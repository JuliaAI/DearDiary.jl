"""
    fetch(::Type{<:UserPermission}, id::Integer)::Optional{UserPermission}

Fetch a [`UserPermission`](@ref) record by ID.

# Arguments
- `::Type{<:UserPermission}`: The type of the record to query.
- `id::Integer`: The ID of the user permission.

# Returns
A [`UserPermission`](@ref) object. If the record does not exist, return `nothing`.
"""
function fetch(::Type{<:UserPermission}, id::Integer)::Optional{UserPermission}
    user_permission = fetch(SQL_SELECT_USERPERMISSION_BY_ID, (id=id,))
    return (user_permission |> isnothing) ? nothing : (user_permission |> UserPermission)
end

"""
    fetch(::Type{<:UserPermission}, user_id::Integer, project_id::Integer)::Optional{UserPermission}

Fetch a [`UserPermission`](@ref) record by [`User`](@ref) and [`Project`](@ref) IDs.

# Arguments
- `::Type{<:UserPermission}`: The type of the record to query.
- `user_id::Integer`: The ID of the user.
- `project_id::Integer`: The ID of the project.

# Returns
A [`UserPermission`](@ref) object. If the record does not exist, return `nothing`.
"""
function fetch(
    ::Type{<:UserPermission}, user_id::Integer, project_id::Integer
)::Optional{UserPermission}
    user_permission = fetch(
        SQL_SELECT_USERPERMISSION_BY_USERID_AND_PROJECT_ID,
        (user_id=user_id, project_id=project_id,),
    )
    return (user_permission |> isnothing) ? nothing : (user_permission |> UserPermission)
end

"""
    insert(::Type{<:UserPermission}, user_id::Integer, project_id::Integer)::Tuple{Optional{<:Integer},UpsertResult}

Insert a [`UserPermission`](@ref) record.

# Arguments
- `::Type{<:UserPermission}`: The type of the record to insert.
- `user_id::Integer`: The ID of the user.
- `project_id::Integer`: The ID of the project.

# Returns
- The inserted record ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists (also for `user_id` and `project_id` combination), [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function insert(
    ::Type{<:UserPermission}, user_id::Integer, project_id::Integer
)::Tuple{Optional{<:Integer},UpsertResult}
    return insert(SQL_INSERT_USERPERMISSION, (user_id=user_id, project_id=project_id))
end

"""
    update(::Type{<:UserPermission}, id::Integer; create_permission::Optional{Bool}=nothing, read_permission::Optional{Bool}=nothing, update_permission::Optional{Bool}=nothing, delete_permission::Optional{Bool}=nothing, manage_permission::Optional{Bool}=nothing)::UpsertResult

# Arguments
- `::Type{<:UserPermission}`: The type of the record to update.
- `id::Integer`: The id of the user permission to update.

# Keyword Arguments
- `create_permission::Optional{Bool}`: The create permission.
- `read_permission::Optional{Bool}`: The read permission.
- `update_permission::Optional{Bool}`: The update permission.
- `delete_permission::Optional{Bool}`: The delete permission.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated,
[`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an
error occurred.
"""
function update(
    ::Type{<:UserPermission}, id::Integer;
    create_permission::Optional{Bool}=nothing,
    read_permission::Optional{Bool}=nothing,
    update_permission::Optional{Bool}=nothing,
    delete_permission::Optional{Bool}=nothing,
    manage_permission::Optional{Bool}=nothing
)::UpsertResult
    fields = (
        create_permission=create_permission,
        read_permission=read_permission,
        update_permission=update_permission,
        delete_permission=delete_permission,
        manage_permission=manage_permission,
    )
    return update(SQL_UPDATE_USERPERMISSION, fetch(UserPermission, id); fields...)
end

"""
    delete(::Type{<:UserPermission}, id::Integer)::Bool

Delete a [`UserPermission`](@ref) record.

# Arguments
- `::Type{<:UserPermission}`: The type of the record to delete.
- `id::Integer`: The id of the user permission to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
delete(::Type{<:UserPermission}, id::Integer)::Bool = delete(SQL_DELETE_USERPERMISSION, id)

"""
    delete(::Type{<:UserPermission}, user::User)::Bool

Delete all [`UserPermission`](@ref) records for a given [`User`](@ref).

# Arguments
- `::Type{<:UserPermission}`: The type of the records to delete.
- `user::User`: The user whose permissions to delete.

# Returns
`true` if the records were successfully deleted, `false` otherwise.
"""
function delete(::Type{<:UserPermission}, user::User)::Bool
    return delete(SQL_DELETE_USERPERMISSIONS_BY_USER_ID, user.id)
end

"""
    delete(::Type{<:UserPermission}, project::Project)::Bool

Delete all [`UserPermission`](@ref) records for a given [`Project`](@ref).

# Arguments
- `::Type{<:UserPermission}`: The type of the records to delete.
- `project::Project`: The project whose permissions to delete.

# Returns
`true` if the records were successfully deleted, `false` otherwise.
"""
function delete(::Type{<:UserPermission}, project::Project)::Bool
    return delete(SQL_DELETE_USERPERMISSIONS_BY_PROJECT_ID, project.id)
end
