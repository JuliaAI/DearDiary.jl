"""
    get_model(id::AbstractString)::Optional{Model}

Get a [`Model`](@ref) by id.

# Arguments
- `id::AbstractString`: The id of the model to query.

# Returns
A [`Model`](@ref) object. If the record does not exist, return `nothing`.
"""
get_model(id::AbstractString)::Optional{Model} = fetch(Model, id)

"""
    get_models(project_id::AbstractString)::Array{Model, 1}

Get all [`Model`](@ref) records registered under a given project.

# Arguments
- `project_id::AbstractString`: The id of the project to query.

# Returns
An array of [`Model`](@ref) objects.
"""
get_models(project_id::AbstractString)::Array{Model,1} = fetch_all(Model, project_id)

"""
    get_models(project_id::AbstractString, page::Pagination)::PaginatedResponse{Model}

Get a page of [`Model`](@ref) records for a project, with `total` count populated.

# Arguments
- `project_id::AbstractString`: The id of the project to query.
- `page::Pagination`: The page bounds (limit + offset).

# Returns
A [`PaginatedResponse`](@ref) of `Model`.
"""
function get_models(project_id::AbstractString, page::Pagination)::PaginatedResponse{Model}
    return fetch_page(Model, project_id, page)
end

"""
    create_model(project_id::AbstractString, name::AbstractString)::NamedTuple{id::Optional{String},status::DataType}

Register a new [`Model`](@ref) under `project_id`.

The name must be unique within the project; a collision returns [`Duplicate`](@ref) instead
of [`Created`](@ref). Registration against a non-existent project returns
[`Unprocessable`](@ref).

# Arguments
- `project_id::AbstractString`: The id of the project that owns the model.
- `name::AbstractString`: The registry name of the model.

# Returns
- The created model id, or `nothing` on failure.
- An [`UpsertResult`](@ref).
"""
function create_model(
    project_id::AbstractString, name::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    project = get_project(project_id)
    if isnothing(project)
        return (id=nothing, status=Unprocessable)
    end

    model_id, model_upsert_result = insert(Model, project_id, name)
    if !(model_upsert_result === Created)
        return (id=nothing, status=model_upsert_result)
    end
    return (id=model_id, status=model_upsert_result)
end

"""
    update_model(id::AbstractString, name::Optional{AbstractString}, description::Optional{AbstractString})::Type{<:UpsertResult}

Update a [`Model`](@ref)'s mutable fields. Any keyword left as `nothing` is left untouched.

# Arguments
- `id::AbstractString`: The id of the model to update.
- `name::Optional{AbstractString}`: The new registry name.
- `description::Optional{AbstractString}`: The new description.

# Returns
An [`UpsertResult`](@ref).
"""
function update_model(
    id::AbstractString,
    name::Optional{AbstractString},
    description::Optional{AbstractString},
)::Type{<:UpsertResult}
    model = get_model(id)
    if isnothing(model)
        return Unprocessable
    end

    should_be_updated = compare_object_fields(model; name=name, description=description)
    if !should_be_updated
        return Updated
    end

    return update(Model, id; name=name, description=description)
end

"""
    delete_model(id::AbstractString)::Bool

Delete a [`Model`](@ref) and cascade every [`ModelVersion`](@ref) under it. The underlying
[`Resource`](@ref) artifacts referenced by those versions are not removed; model
deletion owns only the registry rows, not the artifact bytes.

# Arguments
- `id::AbstractString`: The id of the model to delete.

# Returns
`true` on success, `false` otherwise.
"""
function delete_model(id::AbstractString)::Bool
    model = get_model(id)
    if isnothing(model)
        return false
    end

    delete_all(ModelVersion, id)
    return delete(Model, id)
end

"""
    get_project_id(model::Model)::String

Return the [`Project`](@ref) id that owns the given [`Model`](@ref).

# Arguments
- `model::Model`: The model to inspect.

# Returns
The owning project id.
"""
get_project_id(model::Model)::String = model.project_id
