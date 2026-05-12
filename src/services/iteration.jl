"""
    get_iteration(id::Integer)::Optional{Iteration}

Get a [`Iteration`](@ref) by id.

# Arguments
- `id::Integer`: The id of the iteration to query.

# Returns
A [`Iteration`](@ref) object. If the record does not exist, return `nothing`.
"""
get_iteration(id::Integer)::Optional{Iteration} = fetch(Iteration, id)

"""
    get_iterations(experiment_id::Integer)::Array{Iteration, 1}

Get all [`Iteration`](@ref) for a given experiment.

# Arguments
- `experiment_id::Integer`: The id of the experiment to query.

# Returns
An array of [`Iteration`](@ref) objects.
"""
function get_iterations(experiment_id::Integer)::Array{Iteration,1}
    return fetch_all(Iteration, experiment_id)
end

"""
    get_iterations(experiment_id::Integer, page::Pagination)::PaginatedResponse{Iteration}

Get a page of [`Iteration`](@ref) records for an experiment, with `total` count populated.

# Arguments
- `experiment_id::Integer`: The id of the experiment to query.
- `page::Pagination`: The page bounds (limit + offset).

# Returns
A [`PaginatedResponse`](@ref) of `Iteration`.
"""
function get_iterations(
    experiment_id::Integer, page::Pagination,
)::PaginatedResponse{Iteration}
    return fetch_page(Iteration, experiment_id, page)
end

"""
    create_iteration(experiment_id::Integer)::NamedTuple{id::Optional{<:Int64},status::DataType}

Create a [`Iteration`](@ref).

# Arguments
- `experiment_id::Integer`: The id of the experiment to create the iteration for.

# Returns
- The created iteration ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_iteration(
    experiment_id::Integer
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    experiment = experiment_id |> get_experiment
    if experiment |> isnothing
        return (id=nothing, status=Unprocessable)
    end

    # Only `IN_PROGRESS` experiments accept new iterations.
    if experiment.status_id != (IN_PROGRESS |> Integer)
        return (id=nothing, status=Unprocessable)
    end

    iteration_id, iteration_upsert_result = insert(Iteration, experiment_id)
    if !(iteration_upsert_result === Created)
        return (id=nothing, status=iteration_upsert_result)
    end
    return (id=iteration_id, status=iteration_upsert_result)
end

"""
    update_iteration(id::Int, notes::Optional{AbstractString}, end_date::Optional{DateTime})::Type{<:UpsertResult}

Update a [`Iteration`](@ref) record.

# Arguments
- `id::Integer`: The id of the iteration to update.
- `notes::Optional{AbstractString}`: The new notes for the iteration.
- `end_date::Optional{DateTime}`: The new end date for the iteration.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_iteration(
    id::Integer, notes::Optional{AbstractString}, end_date::Optional{DateTime}
)::Type{<:UpsertResult}
    iteration = id |> get_iteration
    if iteration |> isnothing
        return Unprocessable
    end

    # Once an iteration has ended it is locked: no notes edit, no re-open.
    if !(iteration.end_date |> isnothing)
        return Unprocessable
    end

    should_be_updated = compare_object_fields(iteration; notes=notes, end_date=end_date)
    if !should_be_updated
        return Updated
    end

    return update(Iteration, id; notes=notes, end_date=end_date)
end

"""
    delete_iteration(id::Integer)::Bool

Delete a [`Iteration`](@ref) record.

# Arguments
- `id::Integer`: The id of the iteration to delete. Also deletes all associated [`Parameter`](@ref) and [`Metric`](@ref) records.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_iteration(id::Integer)::Bool
    iteration = fetch(Iteration, id)

    delete_parameters(iteration)
    delete_metrics(iteration)

    return delete(Iteration, id)
end

"""
    with_iteration(f::Function, experiment_id::Integer)

Open a fresh [`Iteration`](@ref) under `experiment_id` via [`create_iteration`](@ref), pass it
to `f`, and finalise `end_date` regardless of whether the body returns normally or throws.
The body's return value is returned on success; exceptions are rethrown after the iteration
has been closed, so a script that crashes mid-run still leaves a terminated iteration in the
database.

# Arguments
- `f::Function`: A unary function that receives the freshly-created [`Iteration`](@ref).
- `experiment_id::Integer`: The id of the [`Experiment`](@ref) that owns the iteration.

# Returns
Whatever `f` returns.
"""
function with_iteration(f::Function, experiment_id::Integer)
    iteration_id, status = experiment_id |> create_iteration
    if !(status === Created)
        throw(ArgumentError(
            "Could not create iteration for experiment $experiment_id: $status",
        ))
    end
    iteration = iteration_id |> get_iteration
    try
        result = f(iteration)
        update_iteration(iteration.id, nothing, now())
        return result
    catch err
        try
            update_iteration(iteration.id, nothing, now())
        catch _
            # Preserve the original exception — a finaliser failure is less informative.
        end
        rethrow(err)
    end
end

"""
    get_project_id(iteration::Iteration)::Optional{Int64}

Return the [`Project`](@ref) id that owns the given [`Iteration`](@ref) by walking up to its
parent [`Experiment`](@ref).

# Arguments
- `iteration::Iteration`: The iteration to inspect.

# Returns
The owning project id, or `nothing` if the parent experiment is missing.
"""
function get_project_id(iteration::Iteration)::Optional{Int64}
    experiment = iteration.experiment_id |> get_experiment
    return experiment |> isnothing ? nothing : (experiment |> get_project_id)
end
