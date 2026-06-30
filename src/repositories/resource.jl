function fetch(::Type{<:Resource}, id::AbstractString)::Optional{Resource}
    resource = fetch(SQL_SELECT_RESOURCE_BY_ID, (id=id,))
    return (isnothing(resource)) ? nothing : (Resource(resource))
end

function fetch_all(::Type{<:Resource}, experiment_id::AbstractString)::Array{Resource,1}
    resources = fetch_all(
        SQL_SELECT_RESOURCES_BY_EXPERIMENT_ID; parameters=(id=experiment_id,)
    )
    return Resource.(resources)
end

function fetch_page(
    ::Type{<:Resource}, experiment_id::AbstractString, page::Pagination
)::PaginatedResponse{Resource}
    paged = fetch_page(
        SQL_SELECT_RESOURCES_BY_EXPERIMENT_ID,
        SQL_COUNT_RESOURCES_BY_EXPERIMENT_ID;
        parameters=(id=experiment_id,),
        page=page,
    )
    return PaginatedResponse{Resource}(
        Resource.(paged.rows), paged.total, page.limit, page.offset
    )
end

function insert(
    ::Type{<:Resource},
    experiment_id::AbstractString,
    name::AbstractString,
    data::AbstractArray{UInt8,1},
    backend::AbstractString,
    uri::AbstractString,
    size_bytes::Integer,
    content_hash::AbstractString,
)::@NamedTuple{id::Optional{String}, status::DataType}
    fields = (
        experiment_id=experiment_id,
        name=name,
        data=data,
        created_date=(string(now())),
        backend=backend,
        uri=uri,
        size_bytes=size_bytes,
        content_hash=content_hash,
    )
    return insert(SQL_INSERT_RESOURCE, fields)
end

# Convenience overload that mirrors the pre-artifact-store signature: bytes go straight
# inline into `resource.data` under the inline backend and metadata columns are computed
# locally. Direct repository-layer callers (notably the test suite) use this to avoid
# pre-computing hash + size at every insertion site.
function insert(
    ::Type{<:Resource},
    experiment_id::AbstractString,
    name::AbstractString,
    data::AbstractArray{UInt8,1},
)::@NamedTuple{id::Optional{String}, status::DataType}
    return insert(
        Resource, experiment_id, name, data, "inline", "", (length(data)), sha256_hex(data)
    )
end

function update(
    ::Type{<:Resource},
    id::AbstractString;
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
    data::Optional{AbstractArray{UInt8,1}}=nothing,
    uri::Optional{AbstractString}=nothing,
    size_bytes::Optional{Integer}=nothing,
    content_hash::Optional{AbstractString}=nothing,
)::Type{<:UpsertResult}
    fields = (
        name=name,
        description=description,
        data=data,
        updated_date=(string(now())),
        uri=uri,
        size_bytes=size_bytes,
        content_hash=content_hash,
    )
    return update(SQL_UPDATE_RESOURCE, fetch(Resource, id); fields...)
end

delete(::Type{<:Resource}, id::AbstractString)::Bool = delete(SQL_DELETE_RESOURCE, id)
