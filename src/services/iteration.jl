"""
    get_iteration(id::AbstractString)::Optional{Iteration}

Get a [`Iteration`](@ref) by id.

# Arguments
- `id::AbstractString`: The id of the iteration to query.

# Returns
A [`Iteration`](@ref) object. If the record does not exist, return `nothing`.
"""
get_iteration(id::AbstractString)::Optional{Iteration} = fetch(Iteration, id)

"""
    get_iterations(experiment_id::AbstractString)::Array{Iteration, 1}

Get all [`Iteration`](@ref) for a given experiment.

# Arguments
- `experiment_id::AbstractString`: The id of the experiment to query.

# Returns
An array of [`Iteration`](@ref) objects.
"""
function get_iterations(experiment_id::AbstractString)::Array{Iteration,1}
    return fetch_all(Iteration, experiment_id)
end

"""
    get_iterations(experiment_id::AbstractString, page::Pagination)::PaginatedResponse{Iteration}

Get a page of [`Iteration`](@ref) records for an experiment, with `total` count populated.

# Arguments
- `experiment_id::AbstractString`: The id of the experiment to query.
- `page::Pagination`: The page bounds (limit + offset).

# Returns
A [`PaginatedResponse`](@ref) of `Iteration`.
"""
function get_iterations(
    experiment_id::AbstractString, page::Pagination
)::PaginatedResponse{Iteration}
    return fetch_page(Iteration, experiment_id, page)
end

"""
    get_child_iterations(parent_id::AbstractString)::Array{Iteration, 1}

Return the direct children of `parent_id`: iterations whose `parent_iteration_id`
points at it, ordered by creation date ascending. Returns an empty array when no children exist.

# Arguments
- `parent_id::AbstractString`: The id of the parent iteration.

# Returns
An array of child [`Iteration`](@ref) objects.
"""
function get_child_iterations(parent_id::AbstractString)::Array{Iteration,1}
    return fetch_children(Iteration, parent_id)
end

"""
    create_iteration(experiment_id::AbstractString; parent_iteration_id=nothing)::NamedTuple{id::Optional{String},status::DataType}

Create a [`Iteration`](@ref).

When `parent_iteration_id` is supplied, the new row is a child run, used to model HPO
trials, nested-CV folds, or distributed-worker fan-outs. The parent must already exist and
must belong to the same `experiment_id`; cross-experiment lineage is rejected with
[`Unprocessable`](@ref).

# Arguments
- `experiment_id::AbstractString`: The id of the experiment to create the iteration for.
- `parent_iteration_id::Optional{AbstractString}`: When set, the id of the parent iteration.

# Returns
- The created iteration ID, or `nothing` on failure.
- An [`UpsertResult`](@ref).
"""
function create_iteration(
    experiment_id::AbstractString; parent_iteration_id::Optional{<:AbstractString}=nothing
)::@NamedTuple{id::Optional{String}, status::DataType}
    experiment = get_experiment(experiment_id)
    if isnothing(experiment)
        return (id=nothing, status=Unprocessable)
    end

    # Only `IN_PROGRESS` experiments accept new iterations.
    if experiment.status_id != (Integer(IN_PROGRESS))
        return (id=nothing, status=Unprocessable)
    end

    if !(isnothing(parent_iteration_id))
        parent = get_iteration(parent_iteration_id)
        if (isnothing(parent)) || parent.experiment_id != experiment_id
            return (id=nothing, status=Unprocessable)
        end
    end

    iteration_id, iteration_upsert_result = insert(
        Iteration, experiment_id; parent_iteration_id=parent_iteration_id
    )
    if !(iteration_upsert_result === Created)
        return (id=nothing, status=iteration_upsert_result)
    end
    return (id=iteration_id, status=iteration_upsert_result)
end

"""
    update_iteration(id::AbstractString, notes::Optional{AbstractString}, end_date::Optional{DateTime}; status_id=nothing, error_message=nothing)::Type{<:UpsertResult}

Update a [`Iteration`](@ref) record.

Once an iteration has been finalised (`end_date` is set), the row is locked: further updates
return [`Unprocessable`](@ref). The intended terminal-state flow is to pass `end_date`,
`status_id`, and (when applicable) `error_message` together in a single call.

# Arguments
- `id::AbstractString`: The id of the iteration to update.
- `notes::Optional{AbstractString}`: The new notes for the iteration.
- `end_date::Optional{DateTime}`: The new end date for the iteration.
- `status_id::Optional{Integer}`: The new [`IterationStatus`](@ref) value. Must be one of the
  four valid integers (`1`..`4`) or `nothing`.
- `error_message::Optional{AbstractString}`: The captured exception text when the iteration
  ended in a [`FAILED`](@ref) state.

# Returns
An [`UpsertResult`](@ref).
"""
function update_iteration(
    id::AbstractString,
    notes::Optional{AbstractString},
    end_date::Optional{DateTime};
    status_id::Optional{<:Integer}=nothing,
    error_message::Optional{AbstractString}=nothing,
)::Type{<:UpsertResult}
    iteration = get_iteration(id)
    if isnothing(iteration)
        return Unprocessable
    end

    # Once an iteration has ended it is locked: no notes edit, no re-open.
    if !(isnothing(iteration.end_date))
        return Unprocessable
    end

    if !(isnothing(status_id)) && !(status_id in (Integer.(instances(IterationStatus))))
        return Unprocessable
    end

    should_be_updated = compare_object_fields(
        iteration;
        notes=notes,
        end_date=end_date,
        status_id=status_id,
        error_message=error_message,
    )
    if !should_be_updated
        return Updated
    end

    return update(
        Iteration,
        id;
        notes=notes,
        end_date=end_date,
        status_id=status_id,
        error_message=error_message,
    )
end

"""
    update_iteration(id::AbstractString, notes::Optional{AbstractString}, end_date::Optional{DateTime}, status::IterationStatus; error_message=nothing)::Type{<:UpsertResult}

[`IterationStatus`](@ref)-typed overload of [`update_iteration`](@ref).
"""
function update_iteration(
    id::AbstractString,
    notes::Optional{AbstractString},
    end_date::Optional{DateTime},
    status::IterationStatus;
    error_message::Optional{AbstractString}=nothing,
)::Type{<:UpsertResult}
    return update_iteration(
        id, notes, end_date; status_id=(Integer(status)), error_message=error_message
    )
end

"""
    snapshot_environment!(iteration_id::AbstractString; entrypoint=PROGRAM_FILE)::Type{<:UpsertResult}

Capture the calling process's reproducibility-relevant state via
[`capture_environment`](@ref) and persist it on iteration `iteration_id`. Idempotent:
re-running on the same iteration overwrites the previous snapshot.

# Arguments
- `iteration_id::AbstractString`: The iteration to attach the snapshot to.
- `entrypoint::AbstractString`: Override the captured script path. Defaults to
  `PROGRAM_FILE`.

# Returns
An [`UpsertResult`](@ref): `Updated` on success, `Unprocessable` if the iteration does
not exist.
"""
function snapshot_environment!(
    iteration_id::AbstractString; entrypoint::AbstractString=PROGRAM_FILE
)::Type{<:UpsertResult}
    iteration = get_iteration(iteration_id)
    if isnothing(iteration)
        return Unprocessable
    end
    snapshot = capture_environment(; entrypoint=entrypoint)
    return update(
        Iteration,
        iteration_id;
        julia_version=snapshot.julia_version,
        git_sha=snapshot.git_sha,
        git_dirty=(Int(snapshot.git_dirty)),
        entrypoint=snapshot.entrypoint,
        project_toml=snapshot.project_toml,
        manifest_toml=snapshot.manifest_toml,
    )
end

"""
    delete_iteration(id::AbstractString)::Bool

Delete a [`Iteration`](@ref) record. Children whose `parent_iteration_id` points at this row
have their reference set to `NULL` by the service layer before the delete; they continue to
exist as standalone iterations until explicitly deleted.

# Arguments
- `id::AbstractString`: The id of the iteration to delete. Also deletes all associated
  [`Parameter`](@ref) and [`Metric`](@ref) records.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_iteration(id::AbstractString)::Bool
    iteration = fetch(Iteration, id)

    delete_parameters(iteration)
    delete_metrics(iteration)

    # Detach children first: DuckDB FKs block deleting a still-referenced parent (no
    # ON DELETE SET NULL action), so this reproduces the old set-null-on-parent-delete.
    nullify_children(Iteration, id)

    return delete(Iteration, id)
end

"""
    with_iteration(f::Function, experiment_id::AbstractString; parent_iteration_id=nothing, snapshot=parent_iteration_id |> isnothing)

Open a fresh [`Iteration`](@ref) under `experiment_id` via [`create_iteration`](@ref), pass it
to `f`, and finalise the iteration's `end_date` and `status_id` regardless of whether the
body returns normally or throws. On a clean return the iteration is marked
[`SUCCEEDED`](@ref); on an exception it is marked [`FAILED`](@ref) with the captured
exception text in `error_message`, and the exception is rethrown so the caller still sees it.

By default the function calls [`snapshot_environment!`](@ref) on the new iteration right
after creation, but only when it has no parent. Driver runs capture the env; child runs
inherit it. Pass `snapshot=true` to force a per-child capture (each child gets its own
snapshot, useful when workers run in different processes) or `snapshot=false` to skip
entirely.

# Arguments
- `f::Function`: A unary function that receives the freshly-created [`Iteration`](@ref).
- `experiment_id::AbstractString`: The id of the [`Experiment`](@ref) that owns the iteration.
- `parent_iteration_id::Optional{AbstractString}`: When set, the new iteration is registered as a
  child of the given parent, useful for HPO sweeps and distributed-worker fan-outs.
- `snapshot::Bool`: Whether to call [`snapshot_environment!`](@ref) after creation.
  Defaults to `true` for driver iterations and `false` for children.

# Returns
Whatever `f` returns.
"""
function with_iteration(
    f::Function,
    experiment_id::AbstractString;
    parent_iteration_id::Optional{<:AbstractString}=nothing,
    snapshot::Bool=(isnothing(parent_iteration_id)),
)
    iteration_id, status = create_iteration(
        experiment_id; parent_iteration_id=parent_iteration_id
    )
    if !(status === Created)
        throw(
            ArgumentError(
                "Could not create iteration for experiment $experiment_id: $status"
            ),
        )
    end
    if snapshot
        snapshot_environment!(iteration_id)
    end
    iteration = get_iteration(iteration_id)
    try
        result = f(iteration)
        update_iteration(iteration.id, nothing, now(), SUCCEEDED)
        return result
    catch err
        try
            update_iteration(
                iteration.id, nothing, now(), FAILED; error_message=sprint(showerror, err)
            )
        catch _
            # Preserve the original exception; a finaliser failure is less informative.
        end
        rethrow(err)
    end
end

"""
    get_project_id(iteration::Iteration)::Optional{String}

Return the [`Project`](@ref) id that owns the given [`Iteration`](@ref) by walking up to its
parent [`Experiment`](@ref).

# Arguments
- `iteration::Iteration`: The iteration to inspect.

# Returns
The owning project id, or `nothing` if the parent experiment is missing.
"""
function get_project_id(iteration::Iteration)::Optional{String}
    experiment = get_experiment(iteration.experiment_id)
    return (isnothing(experiment)) ? nothing : (get_project_id(experiment))
end
