"""
    get_user_by_username(username::String)::Union{User, Nothing}

Get an [`User`](@ref) by username.

# Arguments
- `username::String`: The username of the user to query.

# Returns
An [`User`](@ref) object. If the record does not exist, return `nothing`.
"""
get_user_by_username(username::String)::Union{User,Nothing} = fetch(User, username)

"""
    get_users()::Array{User, 1}

Get all [`User`](@ref).

# Returns
An array of [`User`](@ref) objects.
"""
get_users()::Array{User,1} = User |> fetch_all

"""
    create_user(first_name::String, last_name::String, username::String,
        password::String)::UpsertResult

Create an [`User`](@ref).

# Arguments
- `first_name::String`: The first name of the user.
- `last_name::String`: The last name of the user.
- `username::String`: The username of the user.
- `password::String`: The password of the user.

# Returns
An [`UpsertResult`](@ref). `CREATED` if the record was successfully created, `DUPLICATE` if
the record already exists, `UNPROCESSABLE` if the record violates a constraint, and `ERROR`
if an error occurred while creating the record.
"""
create_user(first_name::String, last_name::String, username::String,
    password::String)::UpsertResult =
    insert(User, first_name, last_name, username, password)
