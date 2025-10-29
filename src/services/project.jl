"""
    get_project_by_id(id::Integer)::Optional{Project}

Get a [`Project`](@ref) by id.

# Arguments
- `id::Integer`: The id of the project to query.

# Returns
A [`Project`](@ref) object. If the record does not exist, return `nothing`.
"""
get_project_by_id(id::Integer)::Optional{Project} = fetch(Project, id)

"""
    get_projects()::Array{Project, 1}

Get all [`Project`](@ref).

# Returns
An array of [`Project`](@ref) objects.
"""
get_projects()::Array{Project,1} = Project |> fetch_all

"""
    create_project(user_id::Integer, project_payload::ProjectCreatePayload)::Tuple{Optional{<:Integer},UpsertResult}

Create a [`Project`](@ref).

# Arguments
- `user_id::Integer`: The id of the user creating the project. The user must have admin privileges.
- `project_payload::ProjectCreatePayload`: The payload for creating an project.

# Returns
An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_project(
    user_id::Integer, project_payload::ProjectCreatePayload
)::Tuple{Optional{<:Integer},UpsertResult}
    user = user_id |> get_user_by_id
    if user |> isnothing || user.is_admin == 0
        return nothing, Unprocessable()
    end

    project_id, project_upsert_result = insert(Project, project_payload.name)
    if !(project_upsert_result isa Created)
        return nothing, project_upsert_result
    end

    _, userpermission_upsert_result = insert(UserPermission, user_id, project_id)
    if !(userpermission_upsert_result isa Created)
        delete(Project, project_id)
        return nothing, userpermission_upsert_result
    end
    return project_id, project_upsert_result
end

"""
    update_project(id::Int, project_payload::ProjectUpdatePayload)::UpsertResult

Update a [`Project`](@ref) record.

# Arguments
- `id::Int`: The id of the project to update.
- `project_payload::ProjectUpdatePayload`: The payload for updating a project.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_project(id::Int, project_payload::ProjectUpdatePayload)::UpsertResult
    project = fetch(Project, id)

    should_be_updated = compare_object_fields(
        project;
        name=project_payload.name,
        description=project_payload.description,
    )
    if !should_be_updated
        return Updated()
    end

    return update(
        Project, id;
        name=project_payload.name,
        description=project_payload.description,
    )
end

"""
    delete_project(id::Int)::Bool

Delete a [`Project`](@ref) record. Also deletes all associated [`UserPermission`](@ref).

# Arguments
- `id::Int`: The id of the project to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_project(id::Int)::Bool
    project = fetch(Project, id)

    delete(UserPermission, project)
    return delete(Project, id)
end
