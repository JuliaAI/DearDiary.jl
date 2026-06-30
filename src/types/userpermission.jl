"""
    UserPermission <: ResultType

A struct representing a user's permissions for a specific project.

Fields
- `id::String`: The unique identifier for the user permission record.
- `user_id::String`: The ID of the user.
- `project_id::String`: The ID of the project.
- `create_permission::Bool`: Permission to create resources.
- `read_permission::Bool`: Permission to read resources.
- `update_permission::Bool`: Permission to update resources.
- `delete_permission::Bool`: Permission to delete resources.
"""
struct UserPermission <: ResultType
    id::String
    user_id::String
    project_id::String
    create_permission::Bool
    read_permission::Bool
    update_permission::Bool
    delete_permission::Bool
end

struct UserPermissionCreatePayload <: UpsertType
    create_permission::Bool
    read_permission::Bool
    update_permission::Bool
    delete_permission::Bool
end

struct UserPermissionUpdatePayload <: UpsertType
    create_permission::Optional{Bool}
    read_permission::Optional{Bool}
    update_permission::Optional{Bool}
    delete_permission::Optional{Bool}
end

"""
    PermissionAction

Abstract supertype representing a CRUD action that a [`UserPermission`](@ref) can grant on a
[`Project`](@ref). Concrete subtypes are dispatched on by [`has_permission`](@ref) to read the
matching boolean field.
"""
abstract type PermissionAction end

"""
    CreatePermission <: PermissionAction

Action that requires `create_permission` on the target [`Project`](@ref).
"""
struct CreatePermission <: PermissionAction end

"""
    ReadPermission <: PermissionAction

Action that requires `read_permission` on the target [`Project`](@ref).
"""
struct ReadPermission <: PermissionAction end

"""
    UpdatePermission <: PermissionAction

Action that requires `update_permission` on the target [`Project`](@ref).
"""
struct UpdatePermission <: PermissionAction end

"""
    DeletePermission <: PermissionAction

Action that requires `delete_permission` on the target [`Project`](@ref).
"""
struct DeletePermission <: PermissionAction end
