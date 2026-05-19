"""
    get_model(client::Client, id::Integer)::Optional{Model}

Fetch a [`Model`](@ref) via `GET /model/{id}`. Returns `nothing` when the server replies 404
(record missing or viewer lacks [`ReadPermission`](@ref) on the owning project) and raises
[`ClientError`](@ref) for other failures.
"""
function get_model(client::Client, id::Integer)::Optional{Model}
    try
        return _json(_request(client, "GET", "/model/$id")) |> Model
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_models(client::Client, project_id::Integer)::Array{Model,1}

Convenience wrapper around the paged form: returns the first page (default limit) of
[`Model`](@ref) records under `project_id` and discards the pagination envelope.
"""
function get_models(client::Client, project_id::Integer)::Array{Model,1}
    return get_models(client, project_id, Pagination(50, 0)).data
end

"""
    get_models(client::Client, project_id::Integer, page::Pagination)::PaginatedResponse{Model}

Fetch a page of [`Model`](@ref) records under `project_id` via
`GET /model/project/{project_id}?limit=…&offset=…`. Requires [`ReadPermission`](@ref) on the
project.
"""
function get_models(
    client::Client, project_id::Integer, page::Pagination,
)::PaginatedResponse{Model}
    response = _request(
        client, "GET", "/model/project/$project_id";
        query=Dict("limit" => page.limit, "offset" => page.offset),
    )
    return _paginated(Model, _json(response))
end

"""
    create_model(client::Client, project_id::Integer, name::AbstractString; description=nothing)::Int64

Register a [`Model`](@ref) under `project_id` via `POST /model/project/{project_id}`.
Requires [`CreatePermission`](@ref) on the project. Returns the new model id.
"""
function create_model(
    client::Client,
    project_id::Integer,
    name::AbstractString;
    description::Optional{AbstractString}=nothing,
)::Int64
    response = _request(
        client, "POST", "/model/project/$project_id";
        body=Dict("name" => name, "description" => description),
    )
    return _json(response)["model_id"]
end

"""
    update_model(client::Client, id::Integer; name=nothing, description=nothing)::Nothing

Patch a [`Model`](@ref) via `PATCH /model/{id}`. Any keyword left as `nothing` is left
untouched server-side. Requires [`UpdatePermission`](@ref) on the owning project.
"""
function update_model(
    client::Client, id::Integer;
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
)::Nothing
    _request(
        client, "PATCH", "/model/$id";
        body=Dict("name" => name, "description" => description),
    )
    return nothing
end

"""
    delete_model(client::Client, id::Integer)::Nothing

Delete a [`Model`](@ref) (and cascade its [`ModelVersion`](@ref)s) via `DELETE /model/{id}`.
The underlying [`Resource`](@ref) artifacts are not removed. Requires
[`DeletePermission`](@ref) on the owning project.
"""
function delete_model(client::Client, id::Integer)::Nothing
    _request(client, "DELETE", "/model/$id")
    return nothing
end
