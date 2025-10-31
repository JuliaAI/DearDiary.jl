function fetch(::Type{<:Metric}, id::Integer)::Optional{Metric}
    metric = fetch(SQL_SELECT_METRIC_BY_ID, (id=id,))
    return (metric |> isnothing) ? nothing : (metric |> Metric)
end

function fetch_all(::Type{<:Metric}, iteration_id::Integer)::Array{Metric,1}
    metrics = fetch_all(
        SQL_SELECT_METRICS_BY_ITERATION_ID;
        parameters=(id=iteration_id,),
    )
    return metrics .|> Metric
end

function insert(
    ::Type{<:Metric}, iteration_id::Integer, key::AbstractString, value::AbstractFloat
)::Tuple{Optional{<:Int64},UpsertResult}
    metrics = (
        iteration_id=iteration_id,
        key=key,
        value=value,
        created_date=(now() |> string),
    )
    return insert(SQL_INSERT_METRIC, metrics)
end

function update(
    ::Type{<:Metric}, id::Integer;
    key::Optional{AbstractString}=nothing,
    value::Optional{AbstractFloat}=nothing,
)::UpsertResult
    fields = (key=key, value=value)
    return update(SQL_UPDATE_METRIC, fetch(Metric, id); fields...)
end

delete(::Type{<:Metric}, id::Integer)::Bool = delete(SQL_DELETE_METRIC, id)

function delete(::Type{<:Metric}, iteration::Iteration)::Bool
    return delete(SQL_DELETE_METRICS_BY_ITERATION_ID, iteration.id)
end
