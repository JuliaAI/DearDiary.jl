"""
    get_modelversion(id::Integer)::Optional{ModelVersion}

Get a [`ModelVersion`](@ref) by id.

# Arguments
- `id::Integer`: The id of the model version to query.

# Returns
A [`ModelVersion`](@ref) object, or `nothing` if no record matches.
"""
get_modelversion(id::Integer)::Optional{ModelVersion} = fetch(ModelVersion, id)

"""
    get_modelversions(model_id::Integer)::Array{ModelVersion, 1}

Get every [`ModelVersion`](@ref) registered under `model_id`, ordered by version ascending.

# Arguments
- `model_id::Integer`: The id of the parent model.

# Returns
An array of [`ModelVersion`](@ref) objects.
"""
function get_modelversions(model_id::Integer)::Array{ModelVersion,1}
    return fetch_all(ModelVersion, model_id)
end

"""
    get_modelversions(model_id::Integer, page::Pagination)::PaginatedResponse{ModelVersion}

Get a page of [`ModelVersion`](@ref) records for a model, with `total` count populated.

# Arguments
- `model_id::Integer`: The id of the parent model.
- `page::Pagination`: The page bounds (limit + offset).

# Returns
A [`PaginatedResponse`](@ref) of `ModelVersion`.
"""
function get_modelversions(
    model_id::Integer, page::Pagination
)::PaginatedResponse{ModelVersion}
    return fetch_page(ModelVersion, model_id, page)
end

"""
    create_modelversion(model_id::Integer, iteration_id::Integer, resource_id::Optional{Integer}, description::AbstractString)::NamedTuple{id::Optional{<:Int64},status::DataType}

Register a new [`ModelVersion`](@ref) under `model_id`. The new version number is the next
free integer for the model (assigned by the database via a subquery on `MAX(version)` +
`UNIQUE(model_id, version)`).

The producing [`Iteration`](@ref) must belong to an [`Experiment`](@ref) in the same project
as the parent [`Model`](@ref); cross-project lineage is rejected with [`Unprocessable`](@ref).
If `resource_id` is supplied, the [`Resource`](@ref) must likewise belong to the same project.
Freshly registered versions start in [`NO_STAGE`](@ref); promote them via
[`update_modelversion`](@ref).

# Arguments
- `model_id::Integer`: The id of the parent model.
- `iteration_id::Integer`: The id of the iteration that produced the checkpoint.
- `resource_id::Optional{Integer}`: The id of the artifact resource, or `nothing` when the
  bytes will be attached later.
- `description::AbstractString`: A free-form description of the version.

# Returns
- The created model version id, or `nothing` on failure.
- An [`UpsertResult`](@ref).
"""
function create_modelversion(
    model_id::Integer,
    iteration_id::Integer,
    resource_id::Optional{<:Integer},
    description::AbstractString,
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    model = get_model(model_id)
    if isnothing(model)
        return (id=nothing, status=Unprocessable)
    end

    iteration = get_iteration(iteration_id)
    if isnothing(iteration)
        return (id=nothing, status=Unprocessable)
    end

    iteration_project_id = get_project_id(iteration)
    if (isnothing(iteration_project_id)) || iteration_project_id != model.project_id
        return (id=nothing, status=Unprocessable)
    end

    if !(isnothing(resource_id))
        resource = get_resource(resource_id)
        if isnothing(resource)
            return (id=nothing, status=Unprocessable)
        end
        resource_project_id = get_project_id(resource)
        if (isnothing(resource_project_id)) || resource_project_id != model.project_id
            return (id=nothing, status=Unprocessable)
        end
    end

    version_id, version_upsert_result = insert(
        ModelVersion,
        model_id,
        iteration_id,
        resource_id,
        (Integer(NO_STAGE)),
        description,
    )
    if !(version_upsert_result === Created)
        return (id=nothing, status=version_upsert_result)
    end
    return (id=version_id, status=version_upsert_result)
end

"""
    update_modelversion(id::Integer, stage_id::Optional{Integer}, description::Optional{AbstractString}, resource_id::Optional{Integer})::Type{<:UpsertResult}

Update a [`ModelVersion`](@ref). `stage_id` must be a valid [`Stage`](@ref) value; promoting a
version to [`PRODUCTION`](@ref) automatically archives every sibling under the same model that
was previously in `PRODUCTION`.

If `resource_id` is supplied, the [`Resource`](@ref) must belong to the same project as the
parent [`Model`](@ref); a mismatch returns [`Unprocessable`](@ref).

# Arguments
- `id::Integer`: The id of the version to update.
- `stage_id::Optional{Integer}`: The new lifecycle stage, or `nothing` to leave unchanged.
- `description::Optional{AbstractString}`: The new description, or `nothing` to leave
  unchanged.
- `resource_id::Optional{Integer}`: The new artifact pointer, or `nothing` to leave unchanged.

# Returns
An [`UpsertResult`](@ref).
"""
function update_modelversion(
    id::Integer,
    stage_id::Optional{Integer},
    description::Optional{AbstractString},
    resource_id::Optional{<:Integer},
)::Type{<:UpsertResult}
    version = get_modelversion(id)
    if isnothing(version)
        return Unprocessable
    end

    if !(isnothing(stage_id)) && !(stage_id in (Integer.(instances(Stage))))
        return Unprocessable
    end

    if !(isnothing(resource_id))
        model = get_model(version.model_id)
        if isnothing(model)
            return Unprocessable
        end
        resource = get_resource(resource_id)
        if isnothing(resource)
            return Unprocessable
        end
        resource_project_id = get_project_id(resource)
        if (isnothing(resource_project_id)) || resource_project_id != model.project_id
            return Unprocessable
        end
    end

    should_be_updated = compare_object_fields(
        version; stage_id=stage_id, description=description, resource_id=resource_id
    )
    if !should_be_updated
        return Updated
    end

    result = update(
        ModelVersion,
        id;
        stage_id=stage_id,
        description=description,
        resource_id=resource_id,
    )
    if result === Updated && stage_id == (Integer(PRODUCTION))
        archive_production_siblings(version.model_id, id)
    end
    return result
end

"""
    update_modelversion(id::Integer, stage::Stage, description::Optional{AbstractString}, resource_id::Optional{Integer})::Type{<:UpsertResult}

[`Stage`](@ref)-typed overload of [`update_modelversion`](@ref).
"""
function update_modelversion(
    id::Integer,
    stage::Stage,
    description::Optional{AbstractString},
    resource_id::Optional{<:Integer},
)::Type{<:UpsertResult}
    return update_modelversion(id, (Integer(stage)), description, resource_id)
end

"""
    delete_modelversion(id::Integer)::Bool

Delete a [`ModelVersion`](@ref). The underlying [`Resource`](@ref) artifact is not
removed; clean it up explicitly via [`delete_resource`](@ref) if it is no longer needed.

# Arguments
- `id::Integer`: The id of the version to delete.

# Returns
`true` on success, `false` otherwise.
"""
delete_modelversion(id::Integer)::Bool = delete(ModelVersion, id)

"""
    get_project_id(version::ModelVersion)::Optional{Int64}

Return the [`Project`](@ref) id that owns `version` by walking up to its parent
[`Model`](@ref).

# Arguments
- `version::ModelVersion`: The version to inspect.

# Returns
The owning project id, or `nothing` if the parent model is missing.
"""
function get_project_id(version::ModelVersion)::Optional{Int64}
    model = get_model(version.model_id)
    return isnothing(model) ? nothing : (get_project_id(model))
end
