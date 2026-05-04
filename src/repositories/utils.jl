"""
    row_to_dict(row::SQLite.Row)::Dict{Symbol,Any}

Transforms a SQLite row into a dictionary.

# Arguments
- `row::SQLite.Row`: The row to transform.

# Returns
A dictionary representation of the row.
"""
function row_to_dict(row::SQLite.Row)::Dict{Symbol,Any}
    return zip((row |> keys), (row |> values)) |> collect |> Dict
end

"""
    fetch(query::AbstractString, parameters::NamedTuple)::Optional{Dict{Symbol,Any}}

Fetch a record from the database.

# Arguments
- `query::AbstractString`: The query to execute.
- `parameters::NamedTuple`: The query parameters.

# Returns
A dictionary of the record. If the record does not exist, return `nothing`.
"""
function fetch(query::AbstractString, parameters::NamedTuple)::Optional{Dict{Symbol,Any}}
    result = DBInterface.execute(get_database(), query, parameters)
    if (result |> isempty)
        return nothing
    end
    return result |> first |> row_to_dict
end

"""
    fetch_all(query::AbstractString; parameters::NamedTuple=(;))::Array{Dict{Symbol,Any},1}

Fetch all records from the database.

# Arguments
- `query::AbstractString`: The query to execute.
- `parameters::NamedTuple`: The query parameters.

# Returns
An array of dictionaries of the records.
"""
function fetch_all(
    query::AbstractString; parameters::NamedTuple=(;)
)::Array{Dict{Symbol,Any},1}
    results = DBInterface.execute(get_database(), query, parameters)
    return [(record |> row_to_dict) for record in results]
end

"""
    fetch_count(query::AbstractString; parameters::NamedTuple=(;))::Int64

Run a `SELECT COUNT(*) AS count FROM ...` query and return the integer count.

# Arguments
- `query::AbstractString`: The COUNT query to execute.
- `parameters::NamedTuple`: The query parameters.

# Returns
The count value, or `0` if the query returns no rows.
"""
function fetch_count(query::AbstractString; parameters::NamedTuple=(;))::Int64
    row = fetch(query, parameters)
    return row |> isnothing ? 0 : Int64(row[:count])
end

"""
    fetch_page(select_query, count_query; parameters, page::Pagination)::@NamedTuple{rows, total}

Execute a SELECT (with `LIMIT :limit OFFSET :offset` appended) and a matching COUNT in one
shot. The page-bounded rows and total count are returned as raw dictionaries; concrete entity
overloads typically wrap these into a [`PaginatedResponse`](@ref).

# Arguments
- `select_query::AbstractString`: SELECT query without `LIMIT`/`OFFSET`. The helper appends them.
- `count_query::AbstractString`: COUNT query that filters by the same parameters.
- `parameters::NamedTuple`: Filter parameters shared by both queries.
- `page::Pagination`: Page bounds.

# Returns
A NamedTuple `(rows::Array{Dict{Symbol,Any},1}, total::Int64)`.
"""
function fetch_page(
    select_query::AbstractString,
    count_query::AbstractString;
    parameters::NamedTuple=(;),
    page::Pagination,
)::@NamedTuple{rows::Array{Dict{Symbol,Any},1}, total::Int64}
    paged_query = select_query * " LIMIT :limit OFFSET :offset"
    paged_params = merge(parameters, (limit=page.limit, offset=page.offset))
    rows = fetch_all(paged_query; parameters=paged_params)
    total = fetch_count(count_query; parameters=parameters)
    return (rows=rows, total=total)
end

"""
    insert(query::AbstractString, parameters::NamedTuple)::NamedTuple{id::Optional{<:Int64},status::DataType}

Insert a record into the database.

# Arguments
- `query::AbstractString`: The query to execute.
- `parameters::NamedTuple`: The query parameters.

# Returns
- The inserted record ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function insert(
    query::AbstractString, parameters::NamedTuple
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    try
        result = DBInterface.execute(get_database(), query, parameters)
        record_id = result |> first |> first
        return (id=record_id, status=Created)
    catch exception
        if occursin("UNIQUE constraint failed", (exception.msg |> string))
            return (id=nothing, status=Duplicate)
        elseif occursin("CHECK constraint failed", (exception.msg |> string))
            return (id=nothing, status=Unprocessable)
        elseif occursin("FOREIGN KEY constraint failed", (exception.msg |> string))
            return (id=nothing, status=Unprocessable)
        else
            return (id=nothing, status=Error)
        end
    end
end

"""
    update(query::AbstractString, object::Optional{<:ResultType}; parameters...)::Type{<:UpsertResult}

Update a record in the database.

# Arguments
- `query::AbstractString`: The query to execute.
- `object::Optional{<:UpsertType}`: The object to update.
- `parameters`: The fields to update.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred.
"""
function update(
    query::AbstractString, object::Optional{<:ResultType}; parameters...
)::Type{<:UpsertResult}
    try
        parameters = parameters |> NamedTuple
        fields = join(
            ["$key=:$key" for key in (parameters |> keys) if parameters[key] |> !isnothing],
            ", ",
        )
        DBInterface.execute(
            get_database(),
            replace(query, "{fields}" => fields),
            merge(parameters, (id=getfield(object, :id),)),
        )
        return Updated
    catch exception
        if occursin("CHECK constraint failed", (exception.msg |> string))
            return Unprocessable
        else
            return Error
        end
    end
end

"""
    delete(query::AbstractString, id::Integer)::Bool

Delete a record from the database.

# Arguments
- `query::AbstractString`: The query to execute.
- `id::Integer`: The ID of the record to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete(query::AbstractString, id::Integer)::Bool
    try
        DBInterface.execute(get_database(), query, (id=id,))
        return true
    catch _
        return false
    end
end
