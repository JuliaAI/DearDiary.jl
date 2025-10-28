"""
    fetch(::Type{<:Experiment}, id::Integer)::Optional{Experiment}

Fetch an [`Experiment`](@ref) by id.

# Arguments
- `::Type{<:Experiment}`: The type of the record to query.
- `id::Integer`: The id of the experiment to query.

# Returns
An [`Experiment`](@ref) object. If the record does not exist, return `nothing`.
"""
function fetch(::Type{<:Experiment}, id::Integer)::Optional{Experiment}
    experiment = fetch(SQL_SELECT_EXPERIMENT_BY_ID, (id=id,))
    return (experiment |> isnothing) ? nothing : (experiment |> Experiment)
end

"""
    fetch_all(::Type{<:Experiment}, project_id::Integer)::Array{Experiment,1}

Fetch all [`Experiment`](@ref) associated with a specific project.

# Arguments
- `::Type{<:Experiment}`: The type of the record to query.
- `project_id::Integer`: The id of the project.

# Returns
An array of [`Experiment`](@ref) objects.
"""
function fetch_all(::Type{<:Experiment}, project_id::Integer)::Array{Experiment,1}
    experiments = fetch_all(
        SQL_SELECT_EXPERIMENTS_BY_PROJECT_ID;
        parameters=(id=project_id,),
    )
    return experiments .|> Experiment
end

"""
    insert(::Type{<:Experiment}, project_id::Integer, status_id::Integer, name::AbstractString)::Tuple{Optional{<:Integer},UpsertResult}

Insert an [`Experiment`](@ref) record.

# Arguments
- `::Type{<:Experiment}`: The type of the record to insert.
- `project_id::Integer`: The id of the project.
- `status_id::Integer`: The id of the status.
- `name::AbstractString`: The name of the experiment.

# Returns
- The inserted record ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function insert(
    ::Type{<:Experiment}, project_id::Integer, status_id::Integer, name::AbstractString
)::Tuple{Optional{<:Integer},UpsertResult}
    parameters = (
        project_id=project_id,
        status_id=status_id,
        name=name,
        created_date=(now() |> string),
    )
    return insert(SQL_INSERT_EXPERIMENT, parameters)
end

"""
    update(::Type{<:Experiment}, id::Integer; status_id::Optional{Integer}=nothing, name::Optional{String}=nothing, description::Optional{String}=nothing, end_date::Optional{DateTime}=nothing)::UpsertResult

Update an [`Experiment`](@ref) record.

# Arguments
- `::Type{<:Experiment}`: The type of the record to update.
- `id::Integer`: The id of the experiment to update.
- `status_id::Optional{Integer}`: The new status id of the experiment.
- `name::Optional{String}`: The new name of the experiment.
- `description::Optional{String}`: The new description of the experiment.
- `end_date::Optional{DateTime}`: The new end date of the experiment.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred.
"""
function update(
    ::Type{<:Experiment}, id::Integer;
    status_id::Optional{Integer}=nothing,
    name::Optional{String}=nothing,
    description::Optional{String}=nothing,
    end_date::Optional{DateTime}=nothing
)::UpsertResult
    fields = (status_id=status_id, name=name, description=description, end_date=end_date)
    return update(SQL_UPDATE_EXPERIMENT, fetch(Experiment, id); fields...)
end

"""
    delete(::Type{<:Experiment}, id::Integer)::Bool

Delete a [`Experiment`](@ref) record.

# Arguments
- `::Type{<:Experiment}`: The type of the record to delete.
- `id::Integer`: The id of the experiment to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
delete(::Type{<:Experiment}, id::Integer)::Bool = delete(SQL_DELETE_EXPERIMENT, id)
