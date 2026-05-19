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

function fetch_page(
    ::Type{<:Resource}, experiment_id::Integer, page::Pagination,
)::PaginatedResponse{Resource}
    paged = fetch_page(
        SQL_SELECT_RESOURCES_BY_EXPERIMENT_ID,
        SQL_COUNT_RESOURCES_BY_EXPERIMENT_ID;
        parameters=(id=experiment_id,), page=page,
    )
    return PaginatedResponse{Resource}(
        paged.rows .|> Resource, paged.total, page.limit, page.offset,
    )
end

function insert(
    ::Type{<:Resource},
    experiment_id::Integer,
    name::AbstractString,
    data::AbstractArray{UInt8,1},
    backend::AbstractString,
    uri::AbstractString,
    size_bytes::Integer,
    content_hash::AbstractString,
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    fields = (
        experiment_id=experiment_id,
        name=name,
        data=data,
        created_date=(now() |> string),
        backend=backend,
        uri=uri,
        size_bytes=size_bytes,
        content_hash=content_hash,
    )
    return insert(SQL_INSERT_RESOURCE, fields)
end

# Convenience overload that mirrors the pre-artifact-store signature: bytes go straight
# inline into `resource.data` under the SQLite backend, and the metadata columns are
# computed locally. Kept so direct repository-layer callers (notably the test suite) do not
# have to pre-compute hash + size at every insertion site.
function insert(
    ::Type{<:Resource},
    experiment_id::Integer,
    name::AbstractString,
    data::AbstractArray{UInt8,1},
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    return insert(
        Resource, experiment_id, name, data,
        "sqlite", "", (data |> length), data |> sha256_hex,
    )
end

function update(
    ::Type{<:Resource}, id::Integer;
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
        updated_date=(now() |> string),
        uri=uri,
        size_bytes=size_bytes,
        content_hash=content_hash,
    )
    return update(SQL_UPDATE_RESOURCE, fetch(Resource, id); fields...)
end

delete(::Type{<:Resource}, id::Integer)::Bool = delete(SQL_DELETE_RESOURCE, id)
