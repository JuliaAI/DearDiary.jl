function fetch(::Type{<:Metric}, id::Integer)::Optional{Metric}
    metric = fetch(SQL_SELECT_METRIC_BY_ID, (id=id,))
    return (isnothing(metric)) ? nothing : (Metric(metric))
end

function fetch_all(::Type{<:Metric}, iteration_id::Integer)::Array{Metric,1}
    metrics = fetch_all(SQL_SELECT_METRICS_BY_ITERATION_ID; parameters=(id=iteration_id,))
    return Metric.(metrics)
end

function fetch_page(
    ::Type{<:Metric}, iteration_id::Integer, page::Pagination
)::PaginatedResponse{Metric}
    paged = fetch_page(
        SQL_SELECT_METRICS_BY_ITERATION_ID,
        SQL_COUNT_METRICS_BY_ITERATION_ID;
        parameters=(id=iteration_id,),
        page=page,
    )
    return PaginatedResponse{Metric}(
        Metric.(paged.rows), paged.total, page.limit, page.offset
    )
end

"""
    next_metric_step(iteration_id::Integer, key::AbstractString)::Int64

Return `max(step) + 1` for the `(iteration_id, key)` series, or `0` when no metric with
that key exists yet. Used by [`create_metric`](@ref) and [`log_metrics`](@ref) to
auto-assign `step` when the caller does not pass one.
"""
function next_metric_step(iteration_id::Integer, key::AbstractString)::Int64
    row = fetch(SQL_SELECT_NEXT_METRIC_STEP, (iteration_id=iteration_id, key=key))
    return (isnothing(row)) ? 0 : (Int64(row[:next_step]))
end

function insert(
    ::Type{<:Metric},
    iteration_id::Integer,
    key::AbstractString,
    value::AbstractFloat,
    step::Integer,
    recorded_at::DateTime,
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    fields = (
        iteration_id=iteration_id,
        key=key,
        value=value,
        step=step,
        recorded_at=(string(recorded_at)),
    )
    return insert(SQL_INSERT_METRIC, fields)
end

function update(
    ::Type{<:Metric},
    id::Integer;
    key::Optional{AbstractString}=nothing,
    value::Optional{AbstractFloat}=nothing,
    step::Optional{Integer}=nothing,
    recorded_at::Optional{DateTime}=nothing,
)::Type{<:UpsertResult}
    # `recorded_at` is stringified for the same reason as iteration/experiment end_date:
    # the database stores it as TEXT so Julia's binary serializer never gets involved.
    recorded_at_text = (isnothing(recorded_at)) ? nothing : (string(recorded_at))
    fields = (key=key, value=value, step=step, recorded_at=recorded_at_text)
    return update(SQL_UPDATE_METRIC, fetch(Metric, id); fields...)
end

delete(::Type{<:Metric}, id::Integer)::Bool = delete(SQL_DELETE_METRIC, id)

function delete(::Type{<:Metric}, iteration::Iteration)::Bool
    return delete(SQL_DELETE_METRICS_BY_ITERATION_ID, iteration.id)
end
