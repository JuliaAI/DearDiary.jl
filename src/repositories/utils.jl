"""
    Base.Dict(row::SQLite.Row)::Dict{Symbol,Any}

Transforms a SQLite row into a dictionary.

# Arguments
- `row::SQLite.Row`: The row to transform.

# Returns
A dictionary representation of the row.
"""
function Base.Dict(row::SQLite.Row)::Dict{Symbol,Any}
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
    return result |> first |> Dict
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
    return [(record |> Dict) for record in results]
end

"""
    insert(query::AbstractString, parameters::NamedTuple)::Tuple{Optional{<:Integer},UpsertResult}

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
)::Tuple{Optional{<:Integer},UpsertResult}
    try
        result = DBInterface.execute(get_database(), query, parameters)
        record_id = result |> first |> first
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
    update(query::AbstractString, object::Optional{<:ResultType}; parameters...)::UpsertResult

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
)::UpsertResult
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
        DBInterface.execute(get_database(),query,(id=id,))
        return true
    catch _
        return false
    end
end
