"""
    get_metric(client::Client, id::Integer)::Optional{Metric}

Fetch a [`Metric`](@ref) via `GET /metric/{id}`. Returns `nothing` when the server replies
404 and raises [`ClientError`](@ref) for other failures.
"""
function get_metric(client::Client, id::Integer)::Optional{Metric}
    try
        return Metric(_json(_request(client, "GET", "/metric/$id")))
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_metrics(client::Client, iteration_id::Integer)::Array{Metric,1}

Returns the first 50 [`Metric`](@ref) rows for `iteration_id`, ordered by `step` ascending.
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
    client::Client, iteration_id::Integer, page::Pagination
)::PaginatedResponse{Metric}
    response = _request(
        client,
        "GET",
        "/metric/iteration/$iteration_id";
        query=Dict("limit" => page.limit, "offset" => page.offset),
    )
    return _paginated(Metric, _json(response))
end

"""
    create_metric(client::Client, iteration_id::Integer, key::AbstractString, value::Real; step=nothing, recorded_at=nothing)::Int64

Append a [`Metric`](@ref) to `iteration_id` via `POST /metric/iteration/{iteration_id}`.

Pass `step=epoch` to position the value in the time series; omit it and the server picks
`max(step) + 1` for the `(iteration_id, key)` series. `recorded_at` defaults to the server
clock when omitted. The parent iteration must not be terminated.
"""
function create_metric(
    client::Client,
    iteration_id::Integer,
    key::AbstractString,
    value::Real;
    step::Optional{Integer}=nothing,
    recorded_at::Optional{DateTime}=nothing,
)::Int64
    response = _request(
        client,
        "POST",
        "/metric/iteration/$iteration_id";
        body=Dict(
            "key" => key,
            "value" => Float64(value),
            "step" => step,
            "recorded_at" => (isnothing(recorded_at)) ? nothing : (string(recorded_at)),
        ),
    )
    return _json(response)["metric_id"]
end

"""
    log_metrics(client::Client, iteration_id::Integer, metrics::AbstractDict{<:AbstractString,<:Real}; step=nothing, recorded_at=nothing)::Array{Int64,1}

Record many metric values at once via `POST /metric/iteration/{iteration_id}/batch`. Cuts
N HTTP round-trips per epoch to one. When `step` is omitted, each `key` independently gets
its own `max(step) + 1` server-side, so per-key counters do not interfere.

```julia
log_metrics(
    client, iter.id,
    Dict("loss" => 0.31, "acc" => 0.94, "val_loss" => 0.42);
    step=epoch,
)
```

Returns the ids of the inserted metrics in the order they were processed.
"""
function log_metrics(
    client::Client,
    iteration_id::Integer,
    metrics::AbstractDict{<:AbstractString,<:Real};
    step::Optional{Integer}=nothing,
    recorded_at::Optional{DateTime}=nothing,
)::Array{Int64,1}
    items = [Dict("key" => String(k), "value" => Float64(v)) for (k, v) in metrics]
    response = _request(
        client,
        "POST",
        "/metric/iteration/$iteration_id/batch";
        body=Dict(
            "step" => step,
            "recorded_at" => (isnothing(recorded_at)) ? nothing : (string(recorded_at)),
            "metrics" => items,
        ),
    )
    return [Int64(id) for id in _json(response)["metric_ids"]]
end

"""
    update_metric(client::Client, id::Integer; key=nothing, value=nothing, step=nothing, recorded_at=nothing)::Nothing

Patch a [`Metric`](@ref) via `PATCH /metric/{id}`. Any keyword left as `nothing` is left
untouched server-side. The owning iteration must not be terminated.
"""
function update_metric(
    client::Client,
    id::Integer;
    key::Optional{AbstractString}=nothing,
    value::Optional{Real}=nothing,
    step::Optional{Integer}=nothing,
    recorded_at::Optional{DateTime}=nothing,
)::Nothing
    _request(
        client,
        "PATCH",
        "/metric/$id";
        body=Dict(
            "key" => key,
            "value" => (isnothing(value)) ? nothing : (Float64(value)),
            "step" => step,
            "recorded_at" => (isnothing(recorded_at)) ? nothing : (string(recorded_at)),
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
