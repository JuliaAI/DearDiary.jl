"""
    fetch(query::AbstractString, params::NamedTuple)::Union{Dict{Symbol,Any},Nothing}

Fetch a record from the database.

# Arguments
- `query::AbstractString`: The query to execute.
- `params::NamedTuple`: The query parameters.

# Returns
A dictionary of the record. If the record does not exist, return `nothing`.
"""
function fetch(query::AbstractString, params::NamedTuple)::Union{Dict{Symbol,Any},Nothing}
    record = DBInterface.execute(get_database(), query, params)
    if (record |> isempty)
        return nothing
    end
    return record |> first |> row_to_dict
end

"""
    fetch_all(query::AbstractString; params::NamedTuple=(;))::Array{Dict{Symbol,Any},1}

Fetch all records from the database.

# Arguments
- `query::AbstractString`: The query to execute.
- `params::NamedTuple`: The query parameters.

# Returns
An array of dictionaries of the records.
"""
fetch_all(query::AbstractString; params::NamedTuple=(;))::Array{Dict{Symbol,Any},1} =
    [(record |> row_to_dict) for record in DBInterface.execute(get_database(), query, params)]

"""
    insert(query::AbstractString, params::NamedTuple
        )::Tuple{Union{Nothing,<:Integer},UpsertResult}

Insert a record into the database.

# Arguments
- `query::AbstractString`: The query to execute.
- `params::NamedTuple`: The query parameters.

# Returns
- The inserted record ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created,
[`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record
violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function insert(query::AbstractString,
    params::NamedTuple)::Tuple{Union{Nothing,<:Integer},UpsertResult}
    try
        record_id = (DBInterface.execute(get_database(), query, params)) |> first |> first
        return record_id, Created()
    catch exception
        if occursin("UNIQUE constraint failed", (exception.msg |> string))
            return nothing, Duplicate()
        elseif occursin("CHECK constraint failed", (exception.msg |> string))
            return nothing, Unprocessable()
        elseif occursin("FOREIGN KEY constraint failed", (exception.msg |> string))
            return nothing, Unprocessable()
        else
            return nothing, Error()
        end
    end
end

"""
    update(query::AbstractString, object::UpsertType, params::NamedTuple)::UpsertResult

Update a record in the database.

# Arguments
- `query::AbstractString`: The query to execute.
- `object::UpsertType`: The object to update.
- `params::NamedTuple`: The query parameters.

# Keyword Arguments
- `database::SQLite.DB`: The database connection.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated,
[`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an
error occurred.
"""
function update(query::AbstractString, object::Union{<:ResultType,Nothing};
    params...)::UpsertResult
    try
        params = params |> NamedTuple
        fields = join(
            ["$key=:$key" for key in (params |> keys) if params[key] |> !isnothing], ", ")
        DBInterface.execute(get_database(), replace(query, "{fields}" => fields),
            merge(params, (id=getfield(object, :id),)))
        return Updated()
    catch exception
        if occursin("CHECK constraint failed", (exception.msg |> string))
            return Unprocessable()
        else
            return Error()
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

"""
    row_to_dict(row::SQLite.Row)::Dict{Symbol, Any}

Convert a SQLite row to a dictionary.
"""
row_to_dict(row::SQLite.Row)::Dict{Symbol,Any} =
    zip((row |> keys), (row |> values)) |> collect |> Dict
