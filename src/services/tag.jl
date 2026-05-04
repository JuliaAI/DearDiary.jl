"""
    get_tag(id::Integer)::Optional{Tag}

Get a [`Tag`](@ref) by id.

# Arguments
- `id::Integer`: The id of the tag to query.

# Returns
A [`Tag`](@ref) object. If the record does not exist, return `nothing`.
"""
get_tag(id::Integer)::Optional{Tag} = fetch(Tag, id)

"""
    get_tag(value::AbstractString)::Optional{Tag}

Get a [`Tag`](@ref) by value.

# Arguments
- `value::AbstractString`: The value of the tag to query.

# Returns
A [`Tag`](@ref) object. If the record does not exist, return `nothing`.
"""
get_tag(value::AbstractString)::Optional{Tag} = fetch(Tag, value)

"""
    get_tags(::Type{<:Project}, project_id::Integer)::Array{Tag, 1}

Get all [`Tag`](@ref) for a given project.

# Arguments
- `::Type{<:Project}`: The project type.
- `project_id::Integer`: The id of the project to query.

# Returns
An array of [`Tag`](@ref) objects.
"""
function get_tags(::Type{<:Project}, project_id::Integer)::Array{Tag,1}
    return fetch_tags(Project, project_id)
end

"""
    get_tags(::Type{<:Experiment}, experiment_id::Integer)::Array{Tag, 1}

Get all [`Tag`](@ref) for a given experiment.

# Arguments
- `::Type{<:Experiment}`: The experiment type.
- `experiment_id::Integer`: The id of the experiment to query.

# Returns
An array of [`Tag`](@ref) objects.
"""
function get_tags(::Type{<:Experiment}, experiment_id::Integer)::Array{Tag,1}
    return fetch_tags(Experiment, experiment_id)
end

"""
    get_tags(::Type{<:Iteration}, iteration_id::Integer)::Array{Tag, 1}

Get all [`Tag`](@ref) for a given iteration.

# Arguments
- `::Type{<:Iteration}`: The iteration type.
- `iteration_id::Integer`: The id of the iteration to query.

# Returns
An array of [`Tag`](@ref) objects.
"""
function get_tags(::Type{<:Iteration}, iteration_id::Integer)::Array{Tag,1}
    return fetch_tags(Iteration, iteration_id)
end

"""
    create_tag(value::AbstractString)::NamedTuple{id::Optional{<:Int64},status::DataType}

Create a [`Tag`](@ref).

# Arguments
- `value::AbstractString`: The value of the tag.

# Returns
- The created tag ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_tag(value::AbstractString)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    return insert(Tag, value)
end

"""
    add_tag(::Type{<:Project}, project_id::Integer, tag_value::AbstractString)::NamedTuple{id::Optional{<:Int64},status::DataType}

Add a tag to a project.

# Arguments
- `::Type{<:Project}`: The project type.
- `project_id::Integer`: The id of the project to add the tag to.
- `tag_value::AbstractString`: The value of the tag to add.

# Returns
- The created project_tag association ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function add_tag(
    ::Type{<:Project}, project_id::Integer, tag_value::AbstractString
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    project = project_id |> get_project
    if project |> isnothing
        return (id=nothing, status=Unprocessable)
    end
    return insert_tag(Project, project_id, tag_value)
end

"""
    add_tag(::Type{<:Experiment}, experiment_id::Integer, tag_value::AbstractString)::NamedTuple{id::Optional{<:Int64},status::DataType}

Add a tag to an experiment.

# Arguments
- `::Type{<:Experiment}`: The experiment type.
- `experiment_id::Integer`: The id of the experiment to add the tag to.
- `tag_value::AbstractString`: The value of the tag to add.

# Returns
- The created experiment_tag association ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function add_tag(
    ::Type{<:Experiment}, experiment_id::Integer, tag_value::AbstractString
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    experiment = experiment_id |> get_experiment
    if experiment |> isnothing
        return (id=nothing, status=Unprocessable)
    end
    return insert_tag(Experiment, experiment_id, tag_value)
end

"""
    add_tag(::Type{<:Iteration}, iteration_id::Integer, tag_value::AbstractString)::NamedTuple{id::Optional{<:Int64},status::DataType}

Add a tag to an iteration.

# Arguments
- `::Type{<:Iteration}`: The iteration type.
- `iteration_id::Integer`: The id of the iteration to add the tag to.
- `tag_value::AbstractString`: The value of the tag to add.

# Returns
- The created iteration_tag association ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function add_tag(
    ::Type{<:Iteration}, iteration_id::Integer, tag_value::AbstractString
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    iteration = iteration_id |> get_iteration
    if iteration |> isnothing
        return (id=nothing, status=Unprocessable)
    end
    # Ended iterations are immutable.
    if !(iteration.end_date |> isnothing)
        return (id=nothing, status=Unprocessable)
    end
    return insert_tag(Iteration, iteration_id, tag_value)
end

"""
    delete_tag(id::Integer)::Bool

Delete a [`Tag`](@ref) record.

# Arguments
- `id::Integer`: The id of the tag to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
delete_tag(id::Integer)::Bool = delete(Tag, id)
