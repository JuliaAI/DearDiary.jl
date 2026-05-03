"""
    User <: ResultType

A struct that represents a user.

Fields
- `id::Int64`: The ID of the user.
- `first_name::String`: The first name of the user.
- `last_name::String`: The last name of the user.
- `username::String`: The username of the user.
- `password::String`: The password of the user. This is a hashed version of the password, not the plain text password.
- `created_date::DateTime`: The date and time the user was created.
- `is_admin::Bool`: Whether the user is an administrator.
"""
struct User <: ResultType
    id::Int64
    first_name::String
    last_name::String
    username::String
    password::String
    created_date::DateTime
    is_admin::Bool
end

struct UserCreatePayload <: UpsertType
    first_name::String
    last_name::String
    username::String
    password::String
end

struct UserUpdatePayload <: UpsertType
    first_name::Optional{String}
    last_name::Optional{String}
    password::Optional{String}
    is_admin::Optional{Bool}
end

struct UserLoginPayload
    username::String
    password::String
end

"""
    UserResponse <: ResultType

A safe-for-API projection of [`User`](@ref) that omits the password hash.

Fields
- `id::Int64`: The ID of the user.
- `first_name::String`: The first name of the user.
- `last_name::String`: The last name of the user.
- `username::String`: The username of the user.
- `created_date::DateTime`: The date and time the user was created.
- `is_admin::Bool`: Whether the user is an administrator.
"""
struct UserResponse <: ResultType
    id::Int64
    first_name::String
    last_name::String
    username::String
    created_date::DateTime
    is_admin::Bool
end
