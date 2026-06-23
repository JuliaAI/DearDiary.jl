"""
    get_experiment(id::Integer)::Optional{Experiment}

Get a [`Experiment`](@ref) by id.

# Arguments
- `id::Integer`: The id of the experiment to query.

# Returns
A [`Experiment`](@ref) object. If the record does not exist, return `nothing`.
"""
get_experiment(id::Integer)::Optional{Experiment} = fetch(Experiment, id)

"""
    get_experiments(project_id::Integer)::Array{Experiment, 1}

Get all [`Experiment`](@ref) for a given project.

# Arguments
- `project_id::Integer`: The id of the project to query.

# Returns
An array of [`Experiment`](@ref) objects.
"""
function get_experiments(project_id::Integer)::Array{Experiment,1}
    return fetch_all(Experiment, project_id)
end

"""
    get_experiments(project_id::Integer, page::Pagination)::PaginatedResponse{Experiment}

Get a page of [`Experiment`](@ref) records for a project, with `total` count populated.

# Arguments
- `project_id::Integer`: The id of the project to query.
- `page::Pagination`: The page bounds (limit + offset).

# Returns
A [`PaginatedResponse`](@ref) of `Experiment`.
"""
function get_experiments(
    project_id::Integer, page::Pagination
)::PaginatedResponse{Experiment}
    return fetch_page(Experiment, project_id, page)
end

"""
    create_experiment(project_id::Integer, status_id::Integer, name::AbstractString)::NamedTuple{id::Optional{<:Int64},status::DataType}

Create a [`Experiment`](@ref).

# Arguments
- `project_id::Integer`: The id of the project to create the experiment for.
- `status_id::Integer`: The status of the experiment.
- `name::AbstractString`: The name of the experiment.

# Returns
- The created experiment ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_experiment(
    project_id::Integer, status_id::Integer, name::AbstractString
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    project = get_project(project_id)
    if isnothing(project)
        return (id=nothing, status=Unprocessable)
    end

    # Experiments must always be created `IN_PROGRESS`. Transitioning to
    # `STOPPED` or `FINISHED` happens later via `update_experiment`.
    if status_id != (Integer(IN_PROGRESS))
        return (id=nothing, status=Unprocessable)
    end

    experiment_id, experiment_upsert_result = insert(
        Experiment, project_id, status_id, name
    )
    if !(experiment_upsert_result === Created)
        return (id=nothing, status=experiment_upsert_result)
    end
    return (id=experiment_id, status=experiment_upsert_result)
end

"""
    create_experiment(project_id::Integer, status::ExperimentStatus, name::AbstractString)::NamedTuple{id::Optional{<:Int64},status::DataType}

Create a [`Experiment`](@ref).

# Arguments
- `project_id::Integer`: The id of the project to create the experiment for.
- `status::ExperimentStatus`: The status of the experiment.
- `name::AbstractString`: The name of the experiment.

# Returns
- The created experiment ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_experiment(
    project_id::Integer, status::ExperimentStatus, name::AbstractString
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    return create_experiment(project_id, (Integer(status)), name)
end

"""
    update_experiment(id::Integer, status_id::Optional{Integer}, name::Optional{AbstractString}, description::Optional{AbstractString}, end_date::Optional{DateTime})::Type{<:UpsertResult}

Update a [`Experiment`](@ref) record.

# Arguments
- `id::Integer`: The id of the experiment to update.
- `status_id::Optional{Integer}`: The new status of the experiment.
- `name::Optional{AbstractString}`: The new name of the experiment.
- `description::Optional{AbstractString}`: The new description of the experiment.
- `end_date::Optional{DateTime}`: The new end date of the experiment.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_experiment(
    id::Integer,
    status_id::Optional{Integer},
    name::Optional{AbstractString},
    description::Optional{AbstractString},
    end_date::Optional{DateTime},
)::Type{<:UpsertResult}
    experiment = fetch(Experiment, id)
    if isnothing(experiment)
        return Unprocessable
    end

    if !(status_id in (Int.(instances(ExperimentStatus))))
        return Unprocessable
    end

    # Reopening: when an experiment transitions back to `IN_PROGRESS` and a
    # previous `end_date` was recorded, that timestamp must be cleared. The
    # experiment is once again live, so it has no end yet.
    reopening = (status_id == (Integer(IN_PROGRESS)) && !(isnothing(experiment.end_date)))
    effective_end_date = reopening ? nothing : end_date

    should_be_updated = compare_object_fields(
        experiment;
        status_id=status_id,
        name=name,
        description=description,
        end_date=effective_end_date,
    )
    if !should_be_updated && !reopening
        return Updated
    end

    return update(
        Experiment,
        id;
        status_id=status_id,
        name=name,
        description=description,
        end_date=effective_end_date,
        clear_end_date=reopening,
    )
end

"""
    update_experiment(id::Integer, status::ExperimentStatus, name::Optional{AbstractString}, description::Optional{AbstractString}, end_date::Optional{DateTime})::Type{<:UpsertResult}

Update a [`Experiment`](@ref) record.

# Arguments
- `id::Integer`: The id of the experiment to update.
- `status::ExperimentStatus`: The new status of the experiment.
- `name::Optional{AbstractString}`: The new name of the experiment.
- `description::Optional{AbstractString}`: The new description of the experiment.
- `end_date::Optional{DateTime}`: The new end date of the experiment.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_experiment(
    id::Integer,
    status::ExperimentStatus,
    name::Optional{AbstractString},
    description::Optional{AbstractString},
    end_date::Optional{DateTime},
)::Type{<:UpsertResult}
    return update_experiment(id, (Integer(status)), name, description, end_date)
end

"""
    delete_experiment(id::Integer)::Bool

Delete a [`Experiment`](@ref) record. Also deletes all associated [`Iteration`](@ref) and [`Resource`](@ref) records.

# Arguments
- `id::Integer`: The id of the experiment to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_experiment(id::Integer)::Bool
    experiment = fetch(Experiment, id)

    for iteration in get_iterations(experiment.id)
        delete_iteration(iteration.id)
    end
    for resource in get_resources(experiment.id)
        delete_resource(resource.id)
    end
    return delete(Experiment, id)
end

"""
    get_project_id(experiment::Experiment)::Int64

Return the [`Project`](@ref) id that owns the given [`Experiment`](@ref).

# Arguments
- `experiment::Experiment`: The experiment to inspect.

# Returns
The owning project id.
"""
get_project_id(experiment::Experiment)::Int64 = experiment.project_id
