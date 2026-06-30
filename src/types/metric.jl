"""
    Metric <: ResultType

A struct representing a metric value logged against an [`Iteration`](@ref). Repeated logs of
the same `key` form a series indexed by `step` and timestamped by `recorded_at`, so a
training script can record a loss curve over many epochs.

Fields
- `id::String`: The ID of the metric.
- `iteration_id::String`: The ID of the iteration this metric belongs to.
- `key::String`: The key/name of the metric (e.g. `"loss"`, `"accuracy"`).
- `value::Float64`: The recorded value.
- `step::Int64`: Position in the time series for this `(iteration_id, key)`. Defaults to
  `max(step) + 1` server-side when not supplied by the caller.
- `recorded_at::DateTime`: When the value was captured. Defaults to the server clock when
  not supplied by the caller.
"""
struct Metric <: ResultType
    id::String
    iteration_id::String
    key::String
    value::Float64
    step::Int64
    recorded_at::DateTime
end

struct MetricCreatePayload <: UpsertType
    key::String
    value::Float64
    step::Optional{Int64}
    recorded_at::Optional{DateTime}
end

struct MetricUpdatePayload <: UpsertType
    key::Optional{String}
    value::Optional{Float64}
    step::Optional{Int64}
    recorded_at::Optional{DateTime}
end

"""
    MetricBatchItem <: UpsertType

A single `(key, value)` pair carried in a [`MetricBatchPayload`](@ref).

Fields
- `key::String`: The metric key.
- `value::Float64`: The recorded value.
"""
struct MetricBatchItem <: UpsertType
    key::String
    value::Float64
end

"""
    MetricBatchPayload <: UpsertType

Payload for `POST /metric/iteration/{iteration_id}/batch`. Records many metric values at
the same `step` and `recorded_at` in a single round-trip.

Fields
- `step::Optional{Int64}`: Shared step for all items. When `nothing`, each `key` gets its
  own `max(step)+1`.
- `recorded_at::Optional{DateTime}`: Shared timestamp. When `nothing`, the server uses `now()`.
- `metrics::Array{MetricBatchItem,1}`: The items to insert.
"""
struct MetricBatchPayload <: UpsertType
    step::Optional{Int64}
    recorded_at::Optional{DateTime}
    metrics::Array{MetricBatchItem,1}
end
