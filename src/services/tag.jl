"""
    get_tag(id::AbstractString)::Optional{Tag}

Get a [`Tag`](@ref) by id.

# Arguments
- `id::AbstractString`: The id of the tag to query.

# Returns
A [`Tag`](@ref) object. If the record does not exist, return `nothing`.
"""
get_tag(id::AbstractString)::Optional{Tag} = fetch(Tag, id)

"""
    get_tag_by_value(value::AbstractString)::Optional{Tag}

Get a [`Tag`](@ref) by value. Distinct from [`get_tag`](@ref) because ids and values are both
strings now and can no longer be told apart by argument type.

# Arguments
- `value::AbstractString`: The value of the tag to query.

# Returns
A [`Tag`](@ref) object. If the record does not exist, return `nothing`.
"""
get_tag_by_value(value::AbstractString)::Optional{Tag} = fetch_by_value(Tag, value)

"""
    get_tags(::Type{<:Project}, project_id::AbstractString)::Array{Tag, 1}

Get all [`Tag`](@ref) for a given project.

# Arguments
- `::Type{<:Project}`: The project type.
- `project_id::AbstractString`: The id of the project to query.

# Returns
An array of [`Tag`](@ref) objects.
"""
function get_tags(::Type{<:Project}, project_id::AbstractString)::Array{Tag,1}
    return fetch_tags(Project, project_id)
end

"""
    get_tags(::Type{<:Experiment}, experiment_id::AbstractString)::Array{Tag, 1}

Get all [`Tag`](@ref) for a given experiment.

# Arguments
- `::Type{<:Experiment}`: The experiment type.
- `experiment_id::AbstractString`: The id of the experiment to query.

# Returns
An array of [`Tag`](@ref) objects.
"""
function get_tags(::Type{<:Experiment}, experiment_id::AbstractString)::Array{Tag,1}
    return fetch_tags(Experiment, experiment_id)
end

"""
    get_tags(::Type{<:Iteration}, iteration_id::AbstractString)::Array{Tag, 1}

Get all [`Tag`](@ref) for a given iteration.

# Arguments
- `::Type{<:Iteration}`: The iteration type.
- `iteration_id::AbstractString`: The id of the iteration to query.

# Returns
An array of [`Tag`](@ref) objects.
"""
function get_tags(::Type{<:Iteration}, iteration_id::AbstractString)::Array{Tag,1}
    return fetch_tags(Iteration, iteration_id)
end

"""
    create_tag(value::AbstractString)::NamedTuple{id::Optional{String},status::DataType}

Create a [`Tag`](@ref).

# Arguments
- `value::AbstractString`: The value of the tag.

# Returns
- The created tag ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_tag(
    value::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    return insert(Tag, value)
end

"""
    add_tag(::Type{<:Project}, project_id::AbstractString, tag_value::AbstractString)::NamedTuple{id::Optional{String},status::DataType}

Add a tag to a project.

# Arguments
- `::Type{<:Project}`: The project type.
- `project_id::AbstractString`: The id of the project to add the tag to.
- `tag_value::AbstractString`: The value of the tag to add.

# Returns
- The created project_tag association ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function add_tag(
    ::Type{<:Project}, project_id::AbstractString, tag_value::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    project = get_project(project_id)
    if isnothing(project)
        return (id=nothing, status=Unprocessable)
    end
    return insert_tag(Project, project_id, tag_value)
end

"""
    add_tag(::Type{<:Experiment}, experiment_id::AbstractString, tag_value::AbstractString)::NamedTuple{id::Optional{String},status::DataType}

Add a tag to an experiment.

# Arguments
- `::Type{<:Experiment}`: The experiment type.
- `experiment_id::AbstractString`: The id of the experiment to add the tag to.
- `tag_value::AbstractString`: The value of the tag to add.

# Returns
- The created experiment_tag association ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function add_tag(
    ::Type{<:Experiment}, experiment_id::AbstractString, tag_value::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    experiment = get_experiment(experiment_id)
    if isnothing(experiment)
        return (id=nothing, status=Unprocessable)
    end
    return insert_tag(Experiment, experiment_id, tag_value)
end

"""
    add_tag(::Type{<:Iteration}, iteration_id::AbstractString, tag_value::AbstractString)::NamedTuple{id::Optional{String},status::DataType}

Add a tag to an iteration.

# Arguments
- `::Type{<:Iteration}`: The iteration type.
- `iteration_id::AbstractString`: The id of the iteration to add the tag to.
- `tag_value::AbstractString`: The value of the tag to add.

# Returns
- The created iteration_tag association ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function add_tag(
    ::Type{<:Iteration}, iteration_id::AbstractString, tag_value::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    iteration = get_iteration(iteration_id)
    if isnothing(iteration)
        return (id=nothing, status=Unprocessable)
    end
    # Ended iterations are immutable.
    if !(isnothing(iteration.end_date))
        return (id=nothing, status=Unprocessable)
    end
    return insert_tag(Iteration, iteration_id, tag_value)
end

"""
    delete_tag(id::AbstractString)::Bool

Delete a [`Tag`](@ref) record.

# Arguments
- `id::AbstractString`: The id of the tag to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
delete_tag(id::AbstractString)::Bool = delete(Tag, id)
