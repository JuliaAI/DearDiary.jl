"""
    get_metric(id::Integer)::Optional{Metric}

Get a [`Metric`](@ref) by id.

# Arguments
- `id::Integer`: The id of the metric to query.

# Returns
A [`Metric`](@ref) object. If the record does not exist, return `nothing`.
"""
get_metric(id::Integer)::Optional{Metric} = fetch(Metric, id)

"""
    get_metrics(iteration_id::Integer)::Array{Metric, 1}

Get all [`Metric`](@ref) for a given iteration, ordered by `step` ascending so the rows
already form a chronological time series.

# Arguments
- `iteration_id::Integer`: The id of the iteration to query.

# Returns
An array of [`Metric`](@ref) objects.
"""
get_metrics(iteration_id::Integer)::Array{Metric,1} = fetch_all(Metric, iteration_id)

"""
    get_metrics(iteration_id::Integer, page::Pagination)::PaginatedResponse{Metric}

Get a page of [`Metric`](@ref) records for an iteration, with `total` count populated.

# Arguments
- `iteration_id::Integer`: The id of the iteration to query.
- `page::Pagination`: The page bounds (limit + offset).

# Returns
A [`PaginatedResponse`](@ref) of `Metric`.
"""
function get_metrics(iteration_id::Integer, page::Pagination)::PaginatedResponse{Metric}
    return fetch_page(Metric, iteration_id, page)
end

"""
    create_metric(iteration_id::Integer, key::AbstractString, value::AbstractFloat; step=nothing, recorded_at=nothing)::NamedTuple{id::Optional{<:Int64},status::DataType}

Create a [`Metric`](@ref).

# Arguments
- `iteration_id::Integer`: The id of the iteration to create the metric for.
- `key::AbstractString`: The key of the metric.
- `value::AbstractFloat`: The value of the metric.
- `step::Optional{Integer}`: Position in the time series. When `nothing`, the next
  `max(step) + 1` value for the `(iteration_id, key)` series is used.
- `recorded_at::Optional{DateTime}`: When the value was captured. When `nothing`, the
  server clock (`now()`) is used.

# Returns
- The created metric ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_metric(
    iteration_id::Integer,
    key::AbstractString,
    value::AbstractFloat;
    step::Optional{Integer}=nothing,
    recorded_at::Optional{DateTime}=nothing,
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    iteration = get_iteration(iteration_id)
    if isnothing(iteration)
        return (id=nothing, status=Unprocessable)
    end

    # Ended iterations are immutable.
    if !(isnothing(iteration.end_date))
        return (id=nothing, status=Unprocessable)
    end

    resolved_step = (isnothing(step)) ? next_metric_step(iteration_id, key) : step
    resolved_recorded_at = (isnothing(recorded_at)) ? now() : recorded_at

    metric_id, metric_upsert_result = insert(
        Metric, iteration_id, key, value, resolved_step, resolved_recorded_at
    )
    if !(metric_upsert_result === Created)
        return (id=nothing, status=metric_upsert_result)
    end
    return (id=metric_id, status=metric_upsert_result)
end

"""
    log_metrics(iteration_id::Integer, metrics::AbstractDict{<:AbstractString,<:AbstractFloat}; step=nothing, recorded_at=nothing)::NamedTuple{ids::Array{Int64,1},status::DataType}

Record many metric values against `iteration_id` in one shot. Every entry shares the same
`recorded_at` (server clock when `nothing`). When `step` is omitted, each `key` independently
gets its own `max(step) + 1`, so per-key counters do not interfere.

Stops at the first failure and returns the ids committed before the failure plus
the failing status; callers can then decide whether to retry or surface the error.

# Arguments
- `iteration_id::Integer`: The id of the iteration to record against.
- `metrics::AbstractDict`: The `key => value` pairs to record.
- `step::Optional{Integer}`: Shared step for every entry, or `nothing` to let each key
  get its own next value.
- `recorded_at::Optional{DateTime}`: Shared timestamp, or `nothing` for `now()`.

# Returns
- `ids::Array{Int64,1}`: The ids of the inserted [`Metric`](@ref) rows in iteration order.
- `status::DataType`: [`Created`](@ref) when every insert succeeded; otherwise the
  [`UpsertResult`](@ref) of the first failing insert.
"""
function log_metrics(
    iteration_id::Integer,
    metrics::AbstractDict{<:AbstractString,<:AbstractFloat};
    step::Optional{Integer}=nothing,
    recorded_at::Optional{DateTime}=nothing,
)::@NamedTuple{ids::Array{Int64,1}, status::DataType}
    iteration = get_iteration(iteration_id)
    if isnothing(iteration)
        return (ids=Int64[], status=Unprocessable)
    end
    if !(isnothing(iteration.end_date))
        return (ids=Int64[], status=Unprocessable)
    end

    resolved_recorded_at = (isnothing(recorded_at)) ? now() : recorded_at

    ids = Int64[]
    for (key, value) in metrics
        resolved_step = (isnothing(step)) ? next_metric_step(iteration_id, key) : step
        id, result = insert(
            Metric, iteration_id, key, Float64(value), resolved_step, resolved_recorded_at
        )
        if !(result === Created)
            return (ids=ids, status=result)
        end
        push!(ids, id)
    end
    return (ids=ids, status=Created)
end

"""
    update_metric(id::Integer, key::Optional{AbstractString}, value::Optional{AbstractFloat}; step=nothing, recorded_at=nothing)::Type{<:UpsertResult}

Update a [`Metric`](@ref) record.

# Arguments
- `id::Integer`: The id of the metric to update.
- `key::Optional{AbstractString}`: The new key for the metric.
- `value::Optional{AbstractFloat}`: The new value for the metric.
- `step::Optional{Integer}`: The new step in the series.
- `recorded_at::Optional{DateTime}`: The new timestamp.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_metric(
    id::Integer,
    key::Optional{AbstractString},
    value::Optional{AbstractFloat};
    step::Optional{Integer}=nothing,
    recorded_at::Optional{DateTime}=nothing,
)::Type{<:UpsertResult}
    metric = get_metric(id)
    if isnothing(metric)
        return Unprocessable
    end

    # Ended iterations are immutable.
    iteration = get_iteration(metric.iteration_id)
    if !(isnothing(iteration)) && !(isnothing(iteration.end_date))
        return Unprocessable
    end

    should_be_updated = compare_object_fields(
        metric; key=key, value=value, step=step, recorded_at=recorded_at
    )
    if !should_be_updated
        return Updated
    end

    return update(Metric, id; key=key, value=value, step=step, recorded_at=recorded_at)
end

"""
    delete_metric(id::Integer)::Bool

Delete a [`Metric`](@ref) record.

# Arguments
- `id::Integer`: The id of the metric to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_metric(id::Integer)::Bool
    metric = get_metric(id)
    if isnothing(metric)
        return false
    end
    iteration = get_iteration(metric.iteration_id)
    if !(isnothing(iteration)) && !(isnothing(iteration.end_date))
        return false
    end
    return delete(Metric, id)
end

"""
    delete_metrics(iteration::Iteration)::Bool

Delete all [`Metric`](@ref) records associated with a given [`Iteration`](@ref).

# Arguments
- `iteration::Iteration`: The iteration whose metrics are to be deleted.

# Returns
`true` if the records were successfully deleted, `false` otherwise.
"""
delete_metrics(iteration::Iteration)::Bool = delete(Metric, iteration)

"""
    get_project_id(metric::Metric)::Optional{Int64}

Return the [`Project`](@ref) id that owns the given [`Metric`](@ref) by walking up to its parent
[`Iteration`](@ref) and [`Experiment`](@ref).

# Arguments
- `metric::Metric`: The metric to inspect.

# Returns
The owning project id, or `nothing` if any ancestor is missing.
"""
function get_project_id(metric::Metric)::Optional{Int64}
    iteration = get_iteration(metric.iteration_id)
    return isnothing(iteration) ? nothing : (get_project_id(iteration))
end
