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
    create_iteration(experiment_id::Integer)::NamedTuple{id::Optional{<:Int64},status::UpsertResult}

Create a [`Iteration`](@ref).

# Arguments
- `experiment_id::Integer`: The id of the experiment to create the iteration for.

# Returns
- The created iteration ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_iteration(
    experiment_id::Integer
)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
    experiment = experiment_id |> get_experiment
    if experiment |> isnothing
        return (id=nothing, status=Unprocessable())
    end

    iteration_id, iteration_upsert_result = insert(Iteration, experiment_id)
    if !(iteration_upsert_result isa Created)
        return (id=nothing, status=iteration_upsert_result)
    end
    return (id=iteration_id, status=iteration_upsert_result)
end

"""
    update_iteration(id::Int, notes::Optional{AbstractString}, end_date::Optional{DateTime})::UpsertResult

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
)::UpsertResult
    iteration = id |> get_iteration
    if iteration |> isnothing
        return Unprocessable()
    end

    should_be_updated = compare_object_fields(iteration; notes=notes, end_date=end_date)
    if !should_be_updated
        return Updated()
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
