"""
    get_resource(client::Client, id::AbstractString)::Optional{Resource}

Fetch the metadata for a [`Resource`](@ref) via `GET /resource/{id}`. The returned struct's
`data` field is always `nothing`; the JSON response carries metadata only. Fetch the
artifact bytes separately with [`read_resource_data`](@ref).

Returns `nothing` when the server replies 404 and raises [`ClientError`](@ref) for other
failures.
"""
function get_resource(client::Client, id::AbstractString)::Optional{Resource}
    try
        return Resource(_json(_request(client, "GET", "/resource/$id")))
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    read_resource_data(client::Client, id::AbstractString)::Optional{Vector{UInt8}}

Download the raw bytes of a [`Resource`](@ref) via `GET /resource/{id}/data`. Returns the
full body as a `Vector{UInt8}`, or `nothing` when the resource does not exist. The endpoint
is backend-agnostic: inline-backed rows hand back the inline bytes, filesystem-backed rows
stream from disk, and S3-backed rows are proxied through the object store.
"""
function read_resource_data(client::Client, id::AbstractString)::Optional{Vector{UInt8}}
    try
        response = _request(client, "GET", "/resource/$id/data")
        return Vector{UInt8}(response.body)
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_resources(client::Client, experiment_id::AbstractString)::Array{Resource,1}

Returns the first page (default limit) of [`Resource`](@ref) records under `experiment_id`,
discarding the pagination envelope.
"""
function get_resources(client::Client, experiment_id::AbstractString)::Array{Resource,1}
    return get_resources(client, experiment_id, Pagination(50, 0)).data
end

"""
    get_resources(client::Client, experiment_id::AbstractString, page::Pagination)::PaginatedResponse{Resource}

Fetch a page of [`Resource`](@ref) records under `experiment_id` via
`GET /resource/experiment/{experiment_id}?limit=…&offset=…`.
"""
function get_resources(
    client::Client, experiment_id::AbstractString, page::Pagination
)::PaginatedResponse{Resource}
    response = _request(
        client,
        "GET",
        "/resource/experiment/$experiment_id";
        query=Dict("limit" => page.limit, "offset" => page.offset),
    )
    return _paginated(Resource, _json(response))
end

"""
    create_resource(client::Client, experiment_id::AbstractString, name::AbstractString, data::AbstractVector{UInt8})::String

Upload a binary [`Resource`](@ref) to `experiment_id` via
`POST /resource/experiment/{experiment_id}` as `multipart/form-data`. The parent
experiment must be [`IN_PROGRESS`](@ref). Returns the new resource id.
"""
function create_resource(
    client::Client,
    experiment_id::AbstractString,
    name::AbstractString,
    data::AbstractVector{UInt8},
)::String
    form = HTTP.Form(Dict("name" => name, "data" => HTTP.Multipart(name, IOBuffer(data))))
    response = _request(
        client, "POST", "/resource/experiment/$experiment_id"; multipart=form
    )
    return _json(response)["resource_id"]
end

"""
    create_resource(client::Client, experiment_id::AbstractString, file_path::AbstractString)::String

Reads bytes from `file_path` and uploads them under the file's base name.
The local API has no file-path overload; this helper exists only on the client.
"""
function create_resource(
    client::Client, experiment_id::AbstractString, file_path::AbstractString
)::String
    bytes = open(read, file_path)
    return create_resource(client, experiment_id, basename(file_path), bytes)
end

"""
    update_resource(client::Client, id::AbstractString; name=nothing, description=nothing, data=nothing)::Nothing

Patch a [`Resource`](@ref) via `PATCH /resource/{id}` as `multipart/form-data`. Any
keyword left as `nothing` is omitted from the multipart body, so partial updates work.
"""
function update_resource(
    client::Client,
    id::AbstractString;
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
    data::Optional{AbstractVector{UInt8}}=nothing,
)::Nothing
    parts = Dict{String,Any}()
    !(isnothing(name)) && (parts["name"] = name)
    !(isnothing(description)) && (parts["description"] = description)
    if !(isnothing(data))
        # Reuse the resource's stored name as the multipart filename when only bytes are given.
        filename = (isnothing(name)) ? "data" : name
        parts["data"] = HTTP.Multipart(filename, IOBuffer(data))
    end
    _request(client, "PATCH", "/resource/$id"; multipart=HTTP.Form(parts))
    return nothing
end

"""
    delete_resource(client::Client, id::AbstractString)::Nothing

Delete a [`Resource`](@ref) via `DELETE /resource/{id}`. Requires
[`DeletePermission`](@ref) on the experiment's project.
"""
function delete_resource(client::Client, id::AbstractString)::Nothing
    _request(client, "DELETE", "/resource/$id")
    return nothing
end
