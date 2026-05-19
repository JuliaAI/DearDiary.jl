"""
    get_modelversion(client::Client, id::Integer)::Optional{ModelVersion}

Fetch a [`ModelVersion`](@ref) via `GET /modelversion/{id}`. Returns `nothing` when the server
replies 404 and raises [`ClientError`](@ref) for other failures.
"""
function get_modelversion(client::Client, id::Integer)::Optional{ModelVersion}
    try
        return _json(_request(client, "GET", "/modelversion/$id")) |> ModelVersion
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_modelversions(client::Client, model_id::Integer)::Array{ModelVersion,1}

Convenience wrapper around the paged form: returns the first page (default limit) of
[`ModelVersion`](@ref) records under `model_id`.
"""
function get_modelversions(client::Client, model_id::Integer)::Array{ModelVersion,1}
    return get_modelversions(client, model_id, Pagination(50, 0)).data
end

"""
    get_modelversions(client::Client, model_id::Integer, page::Pagination)::PaginatedResponse{ModelVersion}

Fetch a page of [`ModelVersion`](@ref) records under `model_id` via
`GET /modelversion/model/{model_id}?limit=…&offset=…`.
"""
function get_modelversions(
    client::Client, model_id::Integer, page::Pagination,
)::PaginatedResponse{ModelVersion}
    response = _request(
        client, "GET", "/modelversion/model/$model_id";
        query=Dict("limit" => page.limit, "offset" => page.offset),
    )
    return _paginated(ModelVersion, _json(response))
end

"""
    create_modelversion(client::Client, model_id::Integer, iteration_id::Integer; resource_id=nothing, description=nothing)::Int64

Register a new [`ModelVersion`](@ref) under `model_id` via
`POST /modelversion/model/{model_id}`. The server assigns the next free per-model version
number. Requires [`CreatePermission`](@ref) on the owning project. Returns the new version id.
"""
function create_modelversion(
    client::Client,
    model_id::Integer,
    iteration_id::Integer;
    resource_id::Optional{<:Integer}=nothing,
    description::Optional{AbstractString}=nothing,
)::Int64
    response = _request(
        client, "POST", "/modelversion/model/$model_id";
        body=Dict(
            "iteration_id" => iteration_id,
            "resource_id" => resource_id,
            "description" => description,
        ),
    )
    return _json(response)["modelversion_id"]
end

"""
    update_modelversion(client::Client, id::Integer; stage_id=nothing, description=nothing, resource_id=nothing)::Nothing

Patch a [`ModelVersion`](@ref) via `PATCH /modelversion/{id}`. Promoting to
[`PRODUCTION`](@ref) automatically archives every sibling that was previously in
`PRODUCTION`. Requires [`UpdatePermission`](@ref) on the owning project.
"""
function update_modelversion(
    client::Client, id::Integer;
    stage_id::Optional{Integer}=nothing,
    description::Optional{AbstractString}=nothing,
    resource_id::Optional{<:Integer}=nothing,
)::Nothing
    _request(
        client, "PATCH", "/modelversion/$id";
        body=Dict(
            "stage_id" => stage_id,
            "description" => description,
            "resource_id" => resource_id,
        ),
    )
    return nothing
end

"""
    update_modelversion(client::Client, id::Integer, stage::Stage; description=nothing, resource_id=nothing)::Nothing

[`Stage`](@ref)-typed overload of [`update_modelversion`](@ref).
"""
function update_modelversion(
    client::Client, id::Integer, stage::Stage;
    description::Optional{AbstractString}=nothing,
    resource_id::Optional{<:Integer}=nothing,
)::Nothing
    return update_modelversion(
        client, id;
        stage_id=(stage |> Integer),
        description=description,
        resource_id=resource_id,
    )
end

"""
    delete_modelversion(client::Client, id::Integer)::Nothing

Delete a [`ModelVersion`](@ref) via `DELETE /modelversion/{id}`. The underlying
[`Resource`](@ref) artifact is not removed. Requires [`DeletePermission`](@ref) on the owning
project.
"""
function delete_modelversion(client::Client, id::Integer)::Nothing
    _request(client, "DELETE", "/modelversion/$id")
    return nothing
end
