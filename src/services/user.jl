"""
    get_user_by_username(username::AbstractString)::Optional{User}

Get an [`User`](@ref) by username.

# Arguments
- `username::AbstractString`: The username of the user to query.

# Returns
An [`User`](@ref) object. If the record does not exist, return `nothing`.
"""
get_user_by_username(username::AbstractString)::Optional{User} = fetch(User, username)

"""
    get_user_by_id(id::Integer)::Optional{User}

Get an [`User`](@ref) by id.

# Arguments
- `id::Integer`: The id of the user to query.

# Returns
An [`User`](@ref) object. If the record does not exist, return `nothing`.
"""
get_user_by_id(id::Integer)::Optional{User} = fetch(User, id)

"""
    get_users()::Array{User, 1}

Get all [`User`](@ref).

# Returns
An array of [`User`](@ref) objects.
"""
get_users()::Array{User,1} = User |> fetch_all

"""
    get_users_by_project_id(project_id::Integer)::Array{User, 1}

Get all [`User`](@ref) associated with a specific project.

# Arguments
- `project_id::Integer`: The ID of the project.

# Returns
An array of [`User`](@ref) objects.
"""
get_users_by_project_id(project_id::Integer)::Array{User,1} = fetch_all(User, project_id)

"""
    create_user(first_name::AbstractString, last_name::AbstractString, username::AbstractString, password::AbstractString)::Tuple{Optional{<:Int64},UpsertResult}

Create an [`User`](@ref).

# Arguments
- `first_name::AbstractString`: The first name of the user.
- `last_name::AbstractString`: The last name of the user.
- `username::AbstractString`: The username of the user.
- `password::AbstractString`: The password of the user.

# Returns
An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_user(
    first_name::AbstractString,
    last_name::AbstractString,
    username::AbstractString,
    password::AbstractString,
)::Tuple{Optional{<:Int64},UpsertResult}
    return insert(
        User,
        first_name,
        last_name,
        username,
        GenerateFromPassword(password) |> String,
    )
end

"""
    update_user(id::Integer, first_name::Optional{AbstractString}, last_name::Optional{AbstractString}, password::Optional{AbstractString}, is_admin::Optional{Bool})::UpsertResult

Update an [`User`](@ref).

# Arguments
- `id::Integer`: The id of the user to update.
- `first_name::Optional{AbstractString}`: The new first name of the user.
- `last_name::Optional{AbstractString}`: The new last name of the user.
- `password::Optional{AbstractString}`: The new password of the user.
- `is_admin::Optional{Bool}`: The new admin status of the user.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no fields were changed), [`Unprocessable`](@ref) if the record violates a constraint or if no fields were provided to update, and [`Error`](@ref) if an error occurred while updating the record.
"""
function update_user(
    id::Integer,
    first_name::Optional{AbstractString},
    last_name::Optional{AbstractString},
    password::Optional{AbstractString},
    is_admin::Optional{Bool},
)::UpsertResult
    user = fetch(User, id)
    if user |> isnothing
        return Unprocessable()
    end

    should_be_updated = compare_object_fields(
        user;
        first_name=first_name,
        last_name=last_name,
        password=password,
        is_admin=is_admin,
    )
    if !should_be_updated
        return Updated()
    end

    if !(password |> isnothing)
        hashed_password = password |> GenerateFromPassword |> String
    end
    return update(
        User, id;
        first_name=first_name,
        last_name=last_name,
        password=(password |> isnothing) ? nothing : hashed_password,
        is_admin=is_admin,
    )
end

"""
    delete_user(id::Integer)::Bool

Delete an [`User`](@ref). Also deletes all associated [`UserPermission`](@ref).

# Arguments
- `id::Integer`: The id of the user to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_user(id::Integer)::Bool
    user = fetch(User, id)

    delete(UserPermission, user)
    return delete(User, id)
end
