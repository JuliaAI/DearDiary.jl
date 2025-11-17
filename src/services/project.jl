"""
    get_project(id::Integer)::Optional{Project}

Get a [`Project`](@ref) by id.

# Arguments
- `id::Integer`: The id of the project to query.

# Returns
A [`Project`](@ref) object. If the record does not exist, return `nothing`.
"""
get_project(id::Integer)::Optional{Project} = fetch(Project, id)

"""
    get_projects()::Array{Project, 1}

Get all [`Project`](@ref).

# Returns
An array of [`Project`](@ref) objects.
"""
get_projects()::Array{Project,1} = Project |> fetch_all

"""
    create_project(user_id::Integer, name::AbstractString)::NamedTuple{id::Optional{<:Int64},status::UpsertResult}

Create a [`Project`](@ref).

# Arguments
- `user_id::Integer`: The id of the user creating the project. The user must have admin privileges.
- `name::AbstractString`: The name of the project.

# Returns
- The created project ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_project(
    user_id::Integer, name::AbstractString
)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
    user = user_id |> get_user
    if user |> isnothing || user.is_admin == 0
        return nothing, Unprocessable()
    end

    project_id, project_upsert_result = insert(Project, name)
    if !(project_upsert_result isa Created)
        return nothing, project_upsert_result
    end

    _, userpermission_upsert_result = insert(UserPermission, user_id, project_id)
    if !(userpermission_upsert_result isa Created)
        delete(Project, project_id)
        return nothing, userpermission_upsert_result
    end
    return (id=project_id, status=project_upsert_result)
end

"""
    create_project(name::AbstractString)::NamedTuple{id::Optional{<:Int64},status::UpsertResult}

Create a [`Project`](@ref). Uses the "default" user to create the project.

# Arguments
- `name::AbstractString`: The name of the project.

# Returns
- The created project ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_project(name::AbstractString)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
    default_user = get_user("default")
    return create_project(default_user.id, name)
end

"""
    update_project(id::Int, name::Optional{AbstractString}, description::Optional{AbstractString})::UpsertResult

Update a [`Project`](@ref) record.

# Arguments
- `id::Integer`: The id of the project to update.
- `name::Optional{AbstractString}`: The new name for the project.
- `description::Optional{AbstractString}`: The new description for the project.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_project(
    id::Integer, name::Optional{AbstractString}, description::Optional{AbstractString}
)::UpsertResult
    project = fetch(Project, id)
    if project |> isnothing
        return Unprocessable()
    end

    should_be_updated = compare_object_fields(project; name=name, description=description)
    if !should_be_updated
        return Updated()
    end

    return update(Project, id; name=name, description=description)
end

"""
    delete_project(id::Integer)::Bool

Delete a [`Project`](@ref) record. Also deletes all associated [`UserPermission`](@ref) and [`Experiment`](@ref) records.

# Arguments
- `id::Integer`: The id of the project to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_project(id::Integer)::Bool
    project = fetch(Project, id)

    for experiment in get_experiments(project.id)
        delete_experiment(experiment.id)
    end
    delete(UserPermission, project)
    return delete(Project, id)
end
