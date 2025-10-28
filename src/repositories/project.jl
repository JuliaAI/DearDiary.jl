"""
    fetch(::Type{<:Project}, id::Integer)::Optional{Project}

Fetch a [`Project`](@ref) record by id.

# Arguments
- `::Type{<:Project}`: The type of the record to query.
- `id::Integer`: The id of the project to query.

# Returns
A [`Project`](@ref) object. If the record does not exist, return `nothing`.
"""
function fetch(::Type{<:Project}, id::Integer)::Optional{Project}
    project = fetch(SQL_SELECT_PROJECT_BY_ID, (id=id,))
    return (project |> isnothing) ? nothing : (project |> Project)
end

"""
    fetch_all(::Type{<:Project})::Array{Project,1}

Fetch all [`Project`](@ref) records.

# Arguments
- `::Type{<:Project}`: The type of the records to fetch.

# Returns
An array of [`Project`](@ref) objects.
"""
function fetch_all(::Type{<:Project})::Array{Project,1}
    return SQL_SELECT_PROJECTS |> fetch_all .|> Project
end

"""
    insert(::Type{<:Project}, name::AbstractString)::Tuple{Optional{<:Integer},UpsertResult}

Insert a [`Project`](@ref) record.

# Arguments
- `::Type{<:Project}`: The type of the record to insert.
- `name::AbstractString`: The name of the project.

# Returns
- The inserted record ID. If an error occurs, `nothing` is returned.
- A [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function insert(
    ::Type{<:Project}, name::AbstractString
)::Tuple{Optional{<:Integer},UpsertResult}
    return insert(SQL_INSERT_PROJECT, (name=name, created_date=(now() |> string)))
end

"""
    update(::Type{<:Project}, name::Optional{String}, description::Optional{String})::UpsertResult

Update a [`Project`](@ref) record.

# Arguments
- `::Type{<:Project}`: The type of the record to update.
- `id::Integer`: The id of the project to update.

# Keyword Arguments
- `name::Optional{String}`: The name of the project.
- `description::Optional{String}`: A brief description of the project.

# Returns
A [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred.
"""
function update(
    ::Type{<:Project}, id::Integer;
    name::Optional{String}=nothing,
    description::Optional{String}=nothing
)::UpsertResult
    fields = (name=name, description=description)
    return update(SQL_UPDATE_PROJECT, fetch(Project, id); fields...)
end

"""
    delete(::Type{<:Project}, id::Integer)::Bool

Delete a [`Project`](@ref) record.

# Arguments
- `::Type{<:Project}`: The type of the record to delete.
- `id::Integer`: The id of the project to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
delete(::Type{<:Project}, id::Integer)::Bool = delete(SQL_DELETE_PROJECT, id)
