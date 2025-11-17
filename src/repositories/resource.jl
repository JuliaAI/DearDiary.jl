function fetch(::Type{<:Resource}, id::Integer)::Optional{Resource}
    resource = fetch(SQL_SELECT_RESOURCE_BY_ID, (id=id,))
    return (resource |> isnothing) ? nothing : (resource |> Resource)
end

function fetch_all(::Type{<:Resource}, experiment_id::Integer)::Array{Resource,1}
    resources = fetch_all(
        SQL_SELECT_RESOURCES_BY_EXPERIMENT_ID;
        parameters=(id=experiment_id,),
    )
    return resources .|> Resource
end

function insert(
    ::Type{<:Resource},
    experiment_id::Integer,
    name::AbstractString,
    data::AbstractArray{UInt8,1},
)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
    fields = (
        experiment_id=experiment_id,
        name=name,
        data=data,
        created_date=(now() |> string),
    )
    return insert(SQL_INSERT_RESOURCE, fields)
end

function update(
    ::Type{<:Resource}, id::Integer;
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
    data::Optional{AbstractArray{UInt8,1}}=nothing,
)::UpsertResult
    fields = (
        name=name,
        description=description,
        data=data,
        updated_date=(now() |> string),
    )
    return update(SQL_UPDATE_RESOURCE, fetch(Resource, id); fields...)
end

delete(::Type{<:Resource}, id::Integer)::Bool = delete(SQL_DELETE_RESOURCE, id)
