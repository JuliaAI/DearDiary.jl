"""
    get_metric(client::Client, id::Integer)::Optional{Metric}

Fetch a [`Metric`](@ref) via `GET /metric/{id}`. Returns `nothing` when the server replies
404 and raises [`ClientError`](@ref) for other failures.
"""
function get_metric(client::Client, id::Integer)::Optional{Metric}
    try
        return _json(_request(client, "GET", "/metric/$id")) |> Metric
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_metrics(client::Client, iteration_id::Integer)::Array{Metric,1}

Convenience wrapper around the paged form: returns the first page (default limit) of
[`Metric`](@ref) records under `iteration_id` and discards the pagination envelope.
"""
function get_metrics(client::Client, iteration_id::Integer)::Array{Metric,1}
    return get_metrics(client, iteration_id, Pagination(50, 0)).data
end

"""
    get_metrics(client::Client, iteration_id::Integer, page::Pagination)::PaginatedResponse{Metric}

Fetch a page of [`Metric`](@ref) records under `iteration_id` via
`GET /metric/iteration/{iteration_id}?limit=…&offset=…`.
"""
function get_metrics(
    client::Client, iteration_id::Integer, page::Pagination,
)::PaginatedResponse{Metric}
    response = _request(
        client, "GET", "/metric/iteration/$iteration_id";
        query=Dict("limit" => page.limit, "offset" => page.offset),
    )
    return _paginated(Metric, _json(response))
end

"""
    create_metric(client::Client, iteration_id::Integer, key::AbstractString, value::Real)::Int64

Append a [`Metric`](@ref) to `iteration_id` via `POST /metric/iteration/{iteration_id}`.
The parent iteration must not be terminated. Returns the new metric id.
"""
function create_metric(
    client::Client,
    iteration_id::Integer,
    key::AbstractString,
    value::Real,
)::Int64
    response = _request(
        client, "POST", "/metric/iteration/$iteration_id";
        body=Dict("key" => key, "value" => value |> Float64),
    )
    return _json(response)["metric_id"]
end

"""
    update_metric(client::Client, id::Integer; key=nothing, value=nothing)::Nothing

Patch a [`Metric`](@ref) via `PATCH /metric/{id}`. Any keyword left as `nothing` is left
untouched. Fails when the parent iteration has already been ended.
"""
function update_metric(
    client::Client, id::Integer;
    key::Optional{AbstractString}=nothing,
    value::Optional{Real}=nothing,
)::Nothing
    _request(
        client, "PATCH", "/metric/$id";
        body=Dict(
            "key" => key,
            "value" => (value |> isnothing) ? nothing : (value |> Float64),
        ),
    )
    return nothing
end

"""
    delete_metric(client::Client, id::Integer)::Nothing

Delete a [`Metric`](@ref) via `DELETE /metric/{id}`. Requires [`DeletePermission`](@ref)
on the iteration's project.
"""
function delete_metric(client::Client, id::Integer)::Nothing
    _request(client, "DELETE", "/metric/$id")
    return nothing
end
