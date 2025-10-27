"""
    get_userpermission_by_user_and_project(user_id::Integer,
        project_id::Integer)::Union{UserPermission, Nothing}

Get a [`UserPermission`](@ref) by [`User`](@ref) id and [`Project`](@ref) IDs.

# Arguments
- `user_id::Integer`: The id of the user.
- `project_id::Integer`: The id of the project.

# Returns
A [`UserPermission`](@ref) object. If the record does not exist, return `nothing`.
"""
get_userpermission_by_user_and_project(user_id::Integer,
    project_id::Integer)::Union{UserPermission,Nothing} =
    fetch(UserPermission, user_id, project_id)

"""
    create_userpermission(user_id::Integer, project_id::Integer,
        userpermission_payload::UserPermissionCreatePayload)::Tuple{Union{Nothing,<:Integer},UpsertResult}

Create a [`UserPermission`](@ref).

# Arguments
- `user_id::Integer`: The id of the user.
- `project_id::Integer`: The id of the project.
- `userpermission_payload::UserPermissionCreatePayload`: The payload for creating a user
permission.

# Returns
An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created,
[`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record
violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_userpermission(user_id::Integer, project_id::Integer,
    userpermission_payload::UserPermissionCreatePayload)::Tuple{Union{Nothing,<:Integer},UpsertResult}
    user = user_id |> get_user_by_id
    if user |> isnothing
        return nothing, Unprocessable()
    end

    project = project_id |> get_project_by_id
    if project |> isnothing
        return nothing, Unprocessable()
    end

    userpermission_id, insert_result = insert(UserPermission, user_id, project_id)
    if !(insert_result isa Created)
        return nothing, insert_result
    end

    update_result = update(UserPermission, userpermission_id;
        create_permission=userpermission_payload.create_permission,
        read_permission=userpermission_payload.read_permission,
        update_permission=userpermission_payload.update_permission,
        delete_permission=userpermission_payload.delete_permission)
    if !(update_result isa Updated)
        delete(UserPermission, userpermission_id)
        return nothing, update_result
    end

    return userpermission_id, insert_result
end

"""
    update_userpermission(userpermission_id::Integer,
        userpermission_payload::UserPermissionUpdatePayload)::UpsertResult

Update a [`UserPermission`](@ref).

# Arguments
- `userpermission_id::Integer`: The id of the user permission to update.
- `userpermission_payload::UserPermissionUpdatePayload`: The payload for updating a user
permission.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or
no fields were changed), [`Unprocessable`](@ref) if the record violates a constraint or if
no fields were provided to update, and [`Error`](@ref) if an error occurred while updating
the record.
"""
function update_userpermission(userpermission_id::Integer,
    userpermission_payload::UserPermissionUpdatePayload)::UpsertResult
    userpermission = fetch(UserPermission, userpermission_id)
    if userpermission |> isnothing
        return Unprocessable()
    end

    should_be_updated = compare_object_fields(userpermission;
        create_permission=userpermission_payload.create_permission,
        read_permission=userpermission_payload.read_permission,
        update_permission=userpermission_payload.update_permission,
        delete_permission=userpermission_payload.delete_permission)
    if !should_be_updated
        return Updated()
    end

    return update(UserPermission, userpermission_id;
        create_permission=userpermission_payload.create_permission,
        read_permission=userpermission_payload.read_permission,
        update_permission=userpermission_payload.update_permission,
        delete_permission=userpermission_payload.delete_permission)
end

"""
    delete_userpermission(userpermission_id::Integer)::Bool

Delete a [`UserPermission`](@ref).

# Arguments
- `userpermission_id::Integer`: The id of the user permission to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
delete_userpermission(userpermission_id::Integer)::Bool =
    delete(UserPermission, userpermission_id)
