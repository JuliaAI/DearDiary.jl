"""
    get_parameter(client::Client, id::Integer)::Optional{Parameter}

Fetch a [`Parameter`](@ref) via `GET /parameter/{id}`. Returns `nothing` when the server
replies 404 and raises [`ClientError`](@ref) for other failures.
"""
function get_parameter(client::Client, id::Integer)::Optional{Parameter}
    try
        return Parameter(_json(_request(client, "GET", "/parameter/$id")))
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_parameters(client::Client, iteration_id::Integer)::Array{Parameter,1}

Returns the first page (default limit) of [`Parameter`](@ref) records under `iteration_id`,
discarding the pagination envelope.
"""
function get_parameters(client::Client, iteration_id::Integer)::Array{Parameter,1}
    return get_parameters(client, iteration_id, Pagination(50, 0)).data
end

"""
    get_parameters(client::Client, iteration_id::Integer, page::Pagination)::PaginatedResponse{Parameter}

Fetch a page of [`Parameter`](@ref) records under `iteration_id` via
`GET /parameter/iteration/{iteration_id}?limit=…&offset=…`.
"""
function get_parameters(
    client::Client, iteration_id::Integer, page::Pagination
)::PaginatedResponse{Parameter}
    response = _request(
        client,
        "GET",
        "/parameter/iteration/$iteration_id";
        query=Dict("limit" => page.limit, "offset" => page.offset),
    )
    return _paginated(Parameter, _json(response))
end

"""
    create_parameter(client::Client, iteration_id::Integer, key::AbstractString, value::AbstractString)::Int64

Append a [`Parameter`](@ref) (string-valued) to `iteration_id` via
`POST /parameter/iteration/{iteration_id}`. The parent iteration must not be terminated;
the server rejects writes to ended iterations. Returns the new parameter id.
"""
function create_parameter(
    client::Client, iteration_id::Integer, key::AbstractString, value::AbstractString
)::Int64
    response = _request(
        client,
        "POST",
        "/parameter/iteration/$iteration_id";
        body=Dict("key" => key, "value" => value),
    )
    return _json(response)["parameter_id"]
end

"""
    create_parameter(client::Client, iteration_id::Integer, key::AbstractString, value::Real)::Int64

`Real`-typed overload of [`create_parameter`](@ref); stringifies `value` before sending so
numeric hyperparameters round-trip through the underlying `TEXT` column unchanged.
"""
function create_parameter(
    client::Client, iteration_id::Integer, key::AbstractString, value::Real
)::Int64
    return create_parameter(client, iteration_id, key, string(value))
end

"""
    update_parameter(client::Client, id::Integer; key=nothing, value=nothing)::Nothing

Patch a [`Parameter`](@ref) via `PATCH /parameter/{id}`. Any keyword left as `nothing` is
left untouched. Fails when the parent iteration has already been ended.
"""
function update_parameter(
    client::Client,
    id::Integer;
    key::Optional{AbstractString}=nothing,
    value::Optional{AbstractString}=nothing,
)::Nothing
    _request(client, "PATCH", "/parameter/$id"; body=Dict("key" => key, "value" => value))
    return nothing
end

"""
    update_parameter(client::Client, id::Integer, value::Real; key=nothing)::Nothing

`Real`-typed overload of [`update_parameter`](@ref); stringifies `value` before sending.
"""
function update_parameter(
    client::Client, id::Integer, value::Real; key::Optional{AbstractString}=nothing
)::Nothing
    return update_parameter(client, id; key=key, value=(string(value)))
end

"""
    delete_parameter(client::Client, id::Integer)::Nothing

Delete a [`Parameter`](@ref) via `DELETE /parameter/{id}`. Requires
[`DeletePermission`](@ref) on the iteration's project.
"""
function delete_parameter(client::Client, id::Integer)::Nothing
    _request(client, "DELETE", "/parameter/$id")
    return nothing
end
