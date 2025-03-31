"""
    fetch(query::String, params::NamedTuple;
        database::SQLite.DB=get_database())::Union{Dict{Symbol,Any},Nothing}

Fetch a record from the database.

# Arguments
- `query::String`: The query to execute.
- `params::NamedTuple`: The query parameters.

# Keyword Arguments
- `database::SQLite.DB`: The database connection.

# Returns
A dictionary of the record. If the record does not exist, return `nothing`.
"""
function fetch(query::String, params::NamedTuple;
    database::SQLite.DB=get_database())::Union{Dict{Symbol,Any},Nothing}
    record = DBInterface.execute(database, query, params)
    if (record |> isempty)
        return nothing
    end
    return record |> first |> row_to_dict
end

"""
    fetch_all(query::String; params::NamedTuple=(;),
        database::SQLite.DB=get_database())::Array{Dict{Symbol,Any},1}

Fetch all records from the database.

# Arguments
- `query::String`: The query to execute.
- `params::NamedTuple`: The query parameters.

# Keyword Arguments
- `database::SQLite.DB`: The database connection.

# Returns
An array of dictionaries of the records.
"""
fetch_all(query::String; params::NamedTuple=(;),
    database::SQLite.DB=get_database())::Array{Dict{Symbol,Any},1} =
    [(record |> row_to_dict) for record in DBInterface.execute(database, query, params)]

"""
    insert(query::String, params::NamedTuple;
        database::SQLite.DB=get_database())::UpsertResult

Insert a record into the database.

# Arguments
- `query::String`: The query to execute.
- `params::NamedTuple`: The query parameters.

# Keyword Arguments
- `database::SQLite.DB`: The database connection.

# Returns
An [`UpsertResult`](@ref). `CREATED` if the record was successfully created, `DUPLICATE` if
the record already exists, `UNPROCESSABLE` if the record violates a constraint, and `ERROR`
if an error occurred while creating the record.
"""
function insert(query::String, params::NamedTuple;
    database::SQLite.DB=get_database())::UpsertResult
    try
        DBInterface.execute(database, query, params)
        return CREATED
    catch exception
        if occursin("UNIQUE constraint failed", (exception.msg |> string))
            return DUPLICATE
        elseif occursin("CHECK constraint failed", (exception.msg |> string))
            return UNPROCESSABLE
        else
            return ERROR
        end
    end
end

"""
    update(query::String, id::Integer, params::NamedTuple;
        database::SQLite.DB=get_database())::UpsertResult

Update a record in the database.

# Arguments
- `query::String`: The query to execute.
- `id::Integer`: The ID of the record to update.
- `params::NamedTuple`: The query parameters.

# Keyword Arguments
- `database::SQLite.DB`: The database connection.

# Returns
An [`UpsertResult`](@ref). `UPDATED` if the record was successfully updated,
`UNPROCESSABLE` if the record violates a constraint, and `ERROR` if an error occurred.
"""
function update(query::String, id::Integer, params::NamedTuple;
    database::SQLite.DB=get_database())::UpsertResult
    try
        fields = join(["$key=:$key" for key in (params |> keys)], ", ")
        DBInterface.execute(database, replace(query, "{fields}" => fields),
            merge(params, (id=id,)))
        return UPDATED
    catch exception
        if occursin("CHECK constraint failed", (exception.msg |> string))
            return UNPROCESSABLE
        else
            return ERROR
        end
    end
end

"""
    delete(query::String, id::Integer; database::SQLite.DB=get_database())::UpsertResult

Delete a record from the database.

# Arguments
- `query::String`: The query to execute.
- `id::Integer`: The ID of the record to delete.

# Keyword Arguments
- `database::SQLite.DB`: The database connection.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete(query::String, id::Integer;
    database::SQLite.DB=get_database())::Bool
    try
        DBInterface.execute(database, query, (id=id,))
        return true
    catch _
        return false
    end
end

"""
    row_to_dict(type::SQLite.Row)::Dict{Symbol, Any}

Convert a SQLite row to a dictionary.
"""
row_to_dict(type::SQLite.Row)::Dict{Symbol,Any} =
    zip((type |> keys), (type |> values)) |> collect |> Dict
