"""
    UserPermission

A struct representing a user's permissions for a specific project.

# Fields
- `id::Integer`: The unique identifier for the user permission record.
- `user_id::Integer`: The ID of the user.
- `project_id::Integer`: The ID of the project.
- `create_permission::Bool`: Permission to create resources.
- `read_permission::Bool`: Permission to read resources.
- `update_permission::Bool`: Permission to update resources.
- `delete_permission::Bool`: Permission to delete resources.
"""
struct UserPermission <: ResultType
    id::Integer
    user_id::Integer
    project_id::Integer
    create_permission::Bool
    read_permission::Bool
    update_permission::Bool
    delete_permission::Bool
end

"""
    UserPermissionCreatePayload

A struct that represents the payload for creating a user permission.

# Fields
- `create_permission::Bool`: Permission to create resources.
- `read_permission::Bool`: Permission to read resources.
- `update_permission::Bool`: Permission to update resources.
- `delete_permission::Bool`: Permission to delete resources.
"""
struct UserPermissionCreatePayload <: UpsertType
    create_permission::Bool
    read_permission::Bool
    update_permission::Bool
    delete_permission::Bool
end

"""
    UserPermissionUpdatePayload

A struct that represents the payload for updating a user permission.

# Fields
- `create_permission::Optional{Bool}`: Permission to create resources, or `nothing` if not updating.
- `read_permission::Optional{Bool}`: Permission to read resources, or `nothing` if not updating.
- `update_permission::Optional{Bool}`: Permission to update resources, or `nothing` if not updating.
- `delete_permission::Optional{Bool}`: Permission to delete resources, or `nothing` if not updating.
"""
struct UserPermissionUpdatePayload <: UpsertType
    create_permission::Optional{Bool}
    read_permission::Optional{Bool}
    update_permission::Optional{Bool}
    delete_permission::Optional{Bool}
end
