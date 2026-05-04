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

Get all [`Metric`](@ref) for a given iteration.

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
function get_metrics(
    iteration_id::Integer, page::Pagination,
)::PaginatedResponse{Metric}
    return fetch_page(Metric, iteration_id, page)
end

"""
    create_metric(iteration_id::Integer, key::AbstractString, value::AbstractFloat)::NamedTuple{id::Optional{<:Int64},status::Type{<:UpsertResult}}

Create a [`Metric`](@ref).

# Arguments
- `iteration_id::Integer`: The id of the iteration to create the metric for.
- `key::AbstractString`: The key of the metric.
- `value::AbstractFloat`: The value of the metric.

# Returns
- The created metric ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_metric(
    iteration_id::Integer, key::AbstractString, value::AbstractFloat
)::@NamedTuple{id::Optional{<:Int64}, status::Type{<:UpsertResult}}
    iteration = iteration_id |> get_iteration
    if iteration |> isnothing
        return (id=nothing, status=Unprocessable)
    end

    metric_id, metric_upsert_result = insert(Metric, iteration_id, key, value)
    if !(metric_upsert_result === Created)
        return (id=nothing, status=metric_upsert_result)
    end
    return (id=metric_id, status=metric_upsert_result)
end

"""
    update_metric(id::Integer, key::Optional{AbstractString}, value::Optional{AbstractFloat})::Type{<:UpsertResult}

Update a [`Metric`](@ref) record.

# Arguments
- `id::Integer`: The id of the metric to update.
- `key::Optional{AbstractString}`: The new key for the metric.
- `value::Optional{AbstractFloat}`: The new value for the metric.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_metric(
    id::Integer, key::Optional{AbstractString}, value::Optional{AbstractFloat}
)::Type{<:UpsertResult}
    metric = id |> get_metric
    if metric |> isnothing
        return Unprocessable
    end

    should_be_updated = compare_object_fields(metric; key=key, value=value)
    if !should_be_updated
        return Updated
    end

    return update(Metric, id; key=key, value=value)
end

"""
    delete_metric(id::Integer)::Bool

Delete a [`Metric`](@ref) record.

# Arguments
- `id::Integer`: The id of the metric to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
delete_metric(id::Integer)::Bool = delete(Metric, id)

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
    iteration = metric.iteration_id |> get_iteration
    return iteration |> isnothing ? nothing : (iteration |> get_project_id)
end
