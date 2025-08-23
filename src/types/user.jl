"""
    User

A struct that represents a user.

# Fields
- `id::Integer`: The ID of the user.
- `first_name::String`: The first name of the user.
- `last_name::String`: The last name of the user.
- `username::String`: The username of the user.
- `password::String`: The password of the user. This is a hashed version of the password,
    not the plain text password.
- `created_at::DateTime`: The date and time the user was created.
- `is_admin::Bool`: Whether the user is an administrator.
"""
struct User <: ResultType
    id::Integer
    first_name::String
    last_name::String
    username::String
    password::String
    created_at::DateTime
    is_admin::Bool
end
User(data::Dict{Symbol,Any}) = User(data[:id], data[:first_name], data[:last_name],
    data[:username], data[:password], (data[:created_at] |> DateTime), data[:is_admin])
User(data::Dict{String,Any}) = User(data["id"], data["first_name"], data["last_name"],
    data["username"], data["password"], (data["created_at"] |> DateTime), data["is_admin"])

"""
    UserCreatePayload

A struct that represents the payload for creating a user.

# Fields
- `first_name::String`: The first name of the user.
- `last_name::String`: The last name of the user.
- `username::String`: The username of the user.
- `password::String`: The password of the user.
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

# Fields
- `first_name::Union{String, Nothing}`: The first name of the user.
- `last_name::Union{String, Nothing}`: The last name of the user.
- `password::Union{String, Nothing}`: The password of the user.
- `is_admin::Union{Bool, Nothing}`: Whether the user is an administrator.
"""
struct UserUpdatePayload <: UpsertType
    first_name::Union{String,Nothing}
    last_name::Union{String,Nothing}
    password::Union{String,Nothing}
    is_admin::Union{Bool,Nothing}
end

"""
    UserLoginPayload

A struct that represents the payload for user login.

# Fields
- `username::String`: The username of the user.

"""
struct UserLoginPayload
    username::String
    password::String
end
