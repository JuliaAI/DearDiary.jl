"""
    get_userpermission(user_id::Integer, project_id::Integer)::Optional{UserPermission}

Get a [`UserPermission`](@ref) by [`User`](@ref) id and [`Project`](@ref) IDs.

# Arguments
- `user_id::Integer`: The id of the user.
- `project_id::Integer`: The id of the project.

# Returns
A [`UserPermission`](@ref) object. If the record does not exist, return `nothing`.
"""
function get_userpermission(
    user_id::Integer, project_id::Integer
)::Optional{UserPermission}
    return fetch(UserPermission, user_id, project_id)
end

"""
    get_userpermissions(::Type{<:Project}, project_id::Integer)::Array{UserPermission,1}

List every [`UserPermission`](@ref) record granting access to the given [`Project`](@ref).

# Arguments
- `::Type{<:Project}`: Dispatch tag selecting the project-scoped listing.
- `project_id::Integer`: The project whose members are being listed.

# Returns
An array of [`UserPermission`](@ref) records (possibly empty).
"""
function get_userpermissions(
    ::Type{<:Project}, project_id::Integer,
)::Array{UserPermission,1}
    return fetch_all(UserPermission, Project, project_id)
end

"""
    get_userpermissions(::Type{<:User}, user_id::Integer)::Array{UserPermission,1}

List every [`UserPermission`](@ref) record held by the given [`User`](@ref).

# Arguments
- `::Type{<:User}`: Dispatch tag selecting the user-scoped listing.
- `user_id::Integer`: The user whose project memberships are being listed.

# Returns
An array of [`UserPermission`](@ref) records (possibly empty).
"""
function get_userpermissions(
    ::Type{<:User}, user_id::Integer,
)::Array{UserPermission,1}
    return fetch_all(UserPermission, User, user_id)
end

"""
    create_userpermission(user_id::Integer, project_id::Integer, create_permission::Bool, read_permission::Bool, update_permission::Bool, delete_permission::Bool)::NamedTuple{id::Optional{<:Int64},status::DataType}

Create a [`UserPermission`](@ref).

# Arguments
- `user_id::Integer`: The id of the user.
- `project_id::Integer`: The id of the project.
- `create_permission::Bool`: Whether the user has create permission.
- `read_permission::Bool`: Whether the user has read permission.
- `update_permission::Bool`: Whether the user has update permission.
- `delete_permission::Bool`: Whether the user has delete permission.

# Returns
- The created userpermission ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_userpermission(
    user_id::Integer,
    project_id::Integer,
    create_permission::Bool,
    read_permission::Bool,
    update_permission::Bool,
    delete_permission::Bool,
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    user = user_id |> get_user
    if user |> isnothing
        return (id=nothing, status=Unprocessable)
    end

    project = project_id |> get_project
    if project |> isnothing
        return (id=nothing, status=Unprocessable)
    end

    userpermission_id, insert_result = insert(UserPermission, user_id, project_id)
    if !(insert_result === Created)
        return (id=nothing, status=insert_result)
    end

    update_result = update(
        UserPermission, userpermission_id;
        create_permission=create_permission,
        read_permission=read_permission,
        update_permission=update_permission,
        delete_permission=delete_permission,
    )
    if !(update_result === Updated)
        delete(UserPermission, userpermission_id)
        return (id=nothing, status=update_result)
    end

    return (id=userpermission_id, status=insert_result)
end

"""
    update_userpermission(id::Integer, create_permission::Optional{Bool}, read_permission::Optional{Bool}, update_permission::Optional{Bool}, delete_permission::Optional{Bool})::Type{<:UpsertResult}

Update a [`UserPermission`](@ref).

# Arguments
- `id::Integer`: The id of the user permission to update.
- `create_permission::Optional{Bool}`: The new create permission.
- `read_permission::Optional{Bool}`: The new read permission.
- `update_permission::Optional{Bool}`: The new update permission.
- `delete_permission::Optional{Bool}`: The new delete permission.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no fields were changed), [`Unprocessable`](@ref) if the record violates a constraint or if no fields were provided to update, and [`Error`](@ref) if an error occurred while updating the record.
"""
function update_userpermission(
    id::Integer,
    create_permission::Optional{Bool},
    read_permission::Optional{Bool},
    update_permission::Optional{Bool},
    delete_permission::Optional{Bool},
)::Type{<:UpsertResult}
    userpermission = fetch(UserPermission, id)
    if userpermission |> isnothing
        return Unprocessable
    end

    should_be_updated = compare_object_fields(
        userpermission;
        create_permission=create_permission,
        read_permission=read_permission,
        update_permission=update_permission,
        delete_permission=delete_permission,
    )
    if !should_be_updated
        return Updated
    end

    return update(
        UserPermission, id;
        create_permission=create_permission,
        read_permission=read_permission,
        update_permission=update_permission,
        delete_permission=delete_permission,
    )
end

"""
    delete_userpermission(id::Integer)::Bool

Delete a [`UserPermission`](@ref).

# Arguments
- `id::Integer`: The id of the user permission to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
delete_userpermission(id::Integer)::Bool = delete(UserPermission, id)

"""
    has_permission(permission::UserPermission, ::Type{<:PermissionAction})::Bool

Return whether `permission` grants the given [`PermissionAction`](@ref) on its
[`Project`](@ref).

# Arguments
- `permission::UserPermission`: The user permission record.
- `::Type{<:PermissionAction}`: The CRUD action being requested, passed as a type tag.

# Returns
`true` if the action is allowed by the permission, `false` otherwise.
"""
has_permission(permission::UserPermission, ::Type{CreatePermission})::Bool = permission.create_permission
has_permission(permission::UserPermission, ::Type{ReadPermission})::Bool = permission.read_permission
has_permission(permission::UserPermission, ::Type{UpdatePermission})::Bool = permission.update_permission
has_permission(permission::UserPermission, ::Type{DeletePermission})::Bool = permission.delete_permission
