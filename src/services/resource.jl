"""
    get_resource(id::AbstractString)::Optional{Resource}

Get a [`Resource`](@ref) by id.

# Arguments
- `id::AbstractString`: The id of the resource to query.

# Returns
A [`Resource`](@ref) object. If the record does not exist, return `nothing`.
"""
get_resource(id::AbstractString)::Optional{Resource} = fetch(Resource, id)

"""
    get_resources(experiment_id::AbstractString)::Array{Resource, 1}

Get all [`Resource`](@ref) for a given experiment.

# Arguments
- `experiment_id::AbstractString`: The id of the experiment to query.

# Returns
An array of [`Resource`](@ref) objects.
"""
get_resources(experiment_id::AbstractString)::Array{Resource,1} = fetch_all(
    Resource, experiment_id
)

"""
    get_resources(experiment_id::AbstractString, page::Pagination)::PaginatedResponse{Resource}

Get a page of [`Resource`](@ref) records for an experiment, with `total` count populated.

# Arguments
- `experiment_id::AbstractString`: The id of the experiment to query.
- `page::Pagination`: The page bounds (limit + offset).

# Returns
A [`PaginatedResponse`](@ref) of `Resource`.
"""
function get_resources(
    experiment_id::AbstractString, page::Pagination
)::PaginatedResponse{Resource}
    return fetch_page(Resource, experiment_id, page)
end

"""
    create_resource(experiment_id::AbstractString, name::AbstractString, data::AbstractArray{UInt8,1})::NamedTuple{id::Optional{String},status::DataType}

Create a new [`Resource`](@ref) record.

# Arguments
- `experiment_id::AbstractString`: The id of the experiment to create the resource for.
- `name::AbstractString`: The name of the resource.
- `data::AbstractArray{UInt8,1}`: The binary data of the resource.

# Returns
- The created resource ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_resource(
    experiment_id::AbstractString, name::AbstractString, data::AbstractArray{UInt8,1}
)::@NamedTuple{id::Optional{String}, status::DataType}
    experiment = get_experiment(experiment_id)
    if isnothing(experiment)
        return (id=nothing, status=Unprocessable)
    end

    # Resources can only be uploaded against an `IN_PROGRESS` experiment.
    if experiment.status_id != (Integer(IN_PROGRESS))
        return (id=nothing, status=Unprocessable)
    end

    # Route the bytes through the configured artifact store. The inline backend computes
    # metadata only and the bytes still go inline into `resource.data` on the INSERT below.
    # External backends (filesystem, S3) write the bytes to their store here and the INSERT
    # stashes an empty BLOB; the canonical bytes are reached via `uri`.
    store = current_artifact_store()
    write_result = write_artifact(store, data)
    inline_bytes = (store isa InlineStore) ? data : UInt8[]

    resource_id, resource_upsert_result = insert(
        Resource,
        experiment_id,
        name,
        inline_bytes,
        backend_id(store),
        write_result.uri,
        write_result.size_bytes,
        write_result.content_hash,
    )
    if !(resource_upsert_result === Created)
        return (id=nothing, status=resource_upsert_result)
    end
    return (id=resource_id, status=resource_upsert_result)
end

"""
    update_resource(id::AbstractString, name::Optional{AbstractString}, description::Optional{AbstractString}, data::Optional{AbstractArray{UInt8,1}})::Type{<:UpsertResult}

Update a [`Resource`](@ref) record.

# Arguments
- `id::AbstractString`: The id of the resource to update.
- `name::Optional{AbstractString}`: The new name for the resource.
- `description::Optional{AbstractString}`: The new description for the resource.
- `data::Optional{AbstractArray{UInt8,1}}`: The new binary data for the resource.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_resource(
    id::AbstractString,
    name::Optional{AbstractString},
    description::Optional{AbstractString},
    data::Optional{AbstractArray{UInt8,1}},
)::Type{<:UpsertResult}
    resource = get_resource(id)
    if isnothing(resource)
        return Unprocessable
    end

    # If new bytes were supplied, route them through the configured store. For non-inline
    # backends this writes a fresh artifact at a new URI; the old artifact is deleted only
    # after the UPDATE commits so a write failure leaves the row pointing at the old bytes.
    new_uri = nothing
    new_size = nothing
    new_hash = nothing
    new_inline_bytes = nothing
    store = current_artifact_store()
    if !(isnothing(data))
        write_result = write_artifact(store, data)
        new_uri = write_result.uri
        new_size = write_result.size_bytes
        new_hash = write_result.content_hash
        new_inline_bytes = (store isa InlineStore) ? (Vector{UInt8}(data)) : UInt8[]
    end

    should_be_updated = compare_object_fields(
        resource; name=name, description=description, data=data
    )
    if !should_be_updated
        return Updated
    end

    result = update(
        Resource,
        id;
        name=name,
        description=description,
        data=new_inline_bytes,
        uri=new_uri,
        size_bytes=new_size,
        content_hash=new_hash,
    )

    # After a successful update with new bytes, the old artifact in the external store is
    # orphaned; drop it. Inline-backed rows are no-ops because the bytes lived in the row.
    if result === Updated && !(isnothing(data)) && !(isempty(resource.uri))
        delete_artifact(store, resource.uri)
    end
    return result
end

"""
    delete_resource(id::AbstractString)::Bool

Delete a [`Resource`](@ref) record. For non-inline backends the underlying artifact bytes
are removed from the store first; inline-backed rows take their bytes down with the row.

# Arguments
- `id::AbstractString`: The id of the resource to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_resource(id::AbstractString)::Bool
    resource = get_resource(id)
    if isnothing(resource)
        return false
    end

    if !(isempty(resource.uri))
        store = current_artifact_store()
        delete_artifact(store, resource.uri)
    end
    return delete(Resource, id)
end

"""
    read_resource_data(id::AbstractString)::Optional{Vector{UInt8}}

Return the raw bytes of the [`Resource`](@ref) identified by `id`, fetching them from the
configured backend. For inline-backed rows this returns `resource.data`; for external
backends it dereferences `resource.uri` through the trait. Returns `nothing` when the row
does not exist.
"""
function read_resource_data(id::AbstractString)::Optional{Vector{UInt8}}
    resource = get_resource(id)
    if isnothing(resource)
        return nothing
    end

    store = current_artifact_store()
    if store isa InlineStore
        return (isnothing(resource.data)) ? UInt8[] : (Vector{UInt8}(resource.data))
    end
    return read_artifact(store, resource.uri, resource.data)
end

"""
    get_project_id(resource::Resource)::Optional{String}

Return the [`Project`](@ref) id that owns the given [`Resource`](@ref) by walking up to its
parent [`Experiment`](@ref).

# Arguments
- `resource::Resource`: The resource to inspect.

# Returns
The owning project id, or `nothing` if the parent experiment is missing.
"""
function get_project_id(resource::Resource)::Optional{String}
    experiment = get_experiment(resource.experiment_id)
    return isnothing(experiment) ? nothing : (get_project_id(experiment))
end
