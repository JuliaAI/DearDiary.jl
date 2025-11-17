"""
    get_resource(id::Integer)::Optional{Resource}

Get a [`Resource`](@ref) by id.

# Arguments
- `id::Integer`: The id of the resource to query.

# Returns
A [`Resource`](@ref) object. If the record does not exist, return `nothing`.
"""
get_resource(id::Integer)::Optional{Resource} = fetch(Resource, id)

"""
    get_resources(experiment_id::Integer)::Array{Resource, 1}

Get all [`Resource`](@ref) for a given experiment.

# Arguments
- `experiment_id::Integer`: The id of the experiment to query.

# Returns
An array of [`Resource`](@ref) objects.
"""
get_resources(experiment_id::Integer)::Array{Resource,1} = fetch_all(Resource, experiment_id)

"""
    create_resource(experiment_id::Integer, name::AbstractString, data::AbstractArray{UInt8,1})::NamedTuple{id::Optional{<:Int64},status::UpsertResult}

Create a new [`Resource`](@ref) record.

# Arguments
- `experiment_id::Integer`: The id of the experiment to create the resource for.
- `name::AbstractString`: The name of the resource.
- `data::AbstractArray{UInt8,1}`: The binary data of the resource.

# Returns
- The created resource ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_resource(
    experiment_id::Integer, name::AbstractString, data::AbstractArray{UInt8,1}
)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
    experiment = experiment_id |> get_experiment
    if experiment |> isnothing
        return (id=nothing, status=Unprocessable())
    end

    resource_id, resource_upsert_result = insert(Resource, experiment_id, name, data)
    if !(resource_upsert_result isa Created)
        return (id=nothing, status=resource_upsert_result)
    end
    return (id=resource_id, status=resource_upsert_result)
end

"""
    update_resource(id::Integer, name::Optional{AbstractString}, description::Optional{AbstractString}, data::Optional{AbstractArray{UInt8,1}})::UpsertResult

Update a [`Resource`](@ref) record.

# Arguments
- `id::Integer`: The id of the resource to update.
- `name::Optional{AbstractString}`: The new name for the resource.
- `description::Optional{AbstractString}`: The new description for the resource.
- `data::Optional{AbstractArray{UInt8,1}}`: The new binary data for the resource.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_resource(
    id::Integer,
    name::Optional{AbstractString},
    description::Optional{AbstractString},
    data::Optional{AbstractArray{UInt8,1}},
)::UpsertResult
    resource = id |> get_resource
    if resource |> isnothing
        return Unprocessable()
    end

    should_be_updated = compare_object_fields(
        resource;
        name=name,
        description=description,
        data=data,
    )
    if !should_be_updated
        return Updated()
    end

    return update(Resource, id; name=name, description=description, data=data)
end

"""
    delete_resource(id::Integer)::Bool

Delete a [`Resource`](@ref) record.

# Arguments
- `id::Integer`: The id of the resource to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
delete_resource(id::Integer)::Bool = delete(Resource, id)
