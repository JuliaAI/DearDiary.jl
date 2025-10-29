"""
    User

A struct that represents a user.

Fields
- `id`: The ID of the user.
- `first_name`: The first name of the user.
- `last_name`: The last name of the user.
- `username`: The username of the user.
- `password`: The password of the user. This is a hashed version of the password, not the plain text password.
- `created_date`: The date and time the user was created.
- `is_admin`: Whether the user is an administrator.
"""
struct User <: ResultType
    id::Integer
    first_name::String
    last_name::String
    username::String
    password::String
    created_date::DateTime
    is_admin::Bool
end

"""
    UserCreatePayload

A struct that represents the payload for creating a user.

Fields
- `first_name`: The first name of the user.
- `last_name`: The last name of the user.
- `username`: The username of the user.
- `password`: The password of the user.
"""
struct UserCreatePayload <: UpsertType
    first_name::String
    last_name::String
    username::String
    password::String
end

"""
    UserUpdatePayload

A struct that represents the payload for updating a user.

Fields
- `first_name`: The first name of the user, or `nothing` if not updating.
- `last_name`: The last name of the user, or `nothing` if not updating.
- `password`: The password of the user, or `nothing` if not updating.
- `is_admin`: Whether the user is an administrator, or `nothing` if not updating.
"""
struct UserUpdatePayload <: UpsertType
    first_name::Optional{String}
    last_name::Optional{String}
    password::Optional{String}
    is_admin::Optional{Bool}
end

"""
    UserLoginPayload

A struct that represents the payload for user login.

Fields
- `username`: The username of the user.
- `password`: The password of the user.
"""
struct UserLoginPayload
    username::String
    password::String
end
