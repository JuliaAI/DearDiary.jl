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
    create_experiment(project_id::Integer, status_id::Integer, name::AbstractString)::NamedTuple{id::Optional{<:Int64},status::UpsertResult}

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
)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
    project = project_id |> get_project
    if project |> isnothing
        return (id=nothing, status=Unprocessable())
    end

    if !(status_id in (Status |> instances .|> Int))
        return (id=nothing, status=Unprocessable())
    end

    experiment_id, experiment_upsert_result = insert(
        Experiment,
        project_id,
        status_id,
        name,
    )
    if !(experiment_upsert_result isa Created)
        return (id=nothing, status=experiment_upsert_result)
    end
    return (id=experiment_id, status=experiment_upsert_result)
end

"""
    create_experiment(project_id::Integer, status::Status, name::AbstractString)::NamedTuple{id::Optional{<:Int64},status::UpsertResult}

Create a [`Experiment`](@ref).

# Arguments
- `project_id::Integer`: The id of the project to create the experiment for.
- `status::Status`: The status of the experiment.
- `name::AbstractString`: The name of the experiment.

# Returns
- The created experiment ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_experiment(
    project_id::Integer, status::Status, name::AbstractString
)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
    return create_experiment(project_id, (status |> Integer), name)
end

"""
    update_experiment(id::Integer, status::Optional{Integer}, name::Optional{AbstractString}, description::Optional{AbstractString}, end_date::Optional{DateTime})::UpsertResult

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
)::UpsertResult
    experiment = fetch(Experiment, id)
    if experiment |> isnothing
        return Unprocessable()
    end

    if !(status_id in (Status |> instances .|> Int))
        return Unprocessable()
    end

    should_be_updated = compare_object_fields(
        experiment;
        status_id=status_id,
        name=name,
        description=description,
        end_date=end_date,
    )
    if !should_be_updated
        return Updated()
    end

    return update(
        Experiment, id;
        status_id=status_id,
        name=name,
        description=description,
        end_date=end_date,
    )
end

"""
    update_experiment(id::Integer, status::Optional{Status}, name::Optional{AbstractString}, description::Optional{AbstractString}, end_date::Optional{DateTime})::UpsertResult

Update a [`Experiment`](@ref) record.

# Arguments
- `id::Integer`: The id of the experiment to update.
- `status_id::Optional{Status}`: The new status of the experiment.
- `name::Optional{AbstractString}`: The new name of the experiment.
- `description::Optional{AbstractString}`: The new description of the experiment.
- `end_date::Optional{DateTime}`: The new end date of the experiment.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_experiment(
    id::Integer,
    status::Optional{Status},
    name::Optional{AbstractString},
    description::Optional{AbstractString},
    end_date::Optional{DateTime},
)::UpsertResult
    return update_experiment(
        id,
        (status |> isnothing) ? nothing : (status |> Integer),
        name,
        description,
        end_date,
    )
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
