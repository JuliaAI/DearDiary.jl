"""
    get_user(id::AbstractString)::Optional{User}

Get an [`User`](@ref) by id.

# Arguments
- `id::AbstractString`: The id of the user to query.

# Returns
An [`User`](@ref) object. If the record does not exist, return `nothing`.
"""
get_user(id::AbstractString)::Optional{User} = fetch(User, id)

"""
    get_user_by_username(username::AbstractString)::Optional{User}

Get an [`User`](@ref) by username. Distinct from [`get_user`](@ref) because ids and usernames
are both strings now and can no longer be told apart by argument type.

# Arguments
- `username::AbstractString`: The username of the user to query.

# Returns
An [`User`](@ref) object. If the record does not exist, return `nothing`.
"""
get_user_by_username(username::AbstractString)::Optional{User} = fetch_by_username(
    User, username
)

"""
    get_users()::Array{User, 1}

Get all [`User`](@ref).

# Returns
An array of [`User`](@ref) objects.
"""
get_users()::Array{User,1} = fetch_all(User)

"""
    create_user(first_name::AbstractString, last_name::AbstractString, username::AbstractString, password::AbstractString)::NamedTuple{id::Optional{String},status::DataType}

Create an [`User`](@ref).

# Arguments
- `first_name::AbstractString`: The first name of the user.
- `last_name::AbstractString`: The last name of the user.
- `username::AbstractString`: The username of the user.
- `password::AbstractString`: The password of the user.

# Returns
- The created user ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_user(
    first_name::AbstractString,
    last_name::AbstractString,
    username::AbstractString,
    password::AbstractString,
)::@NamedTuple{id::Optional{String}, status::DataType}
    return insert(
        User, first_name, last_name, username, String(GenerateFromPassword(password))
    )
end

"""
    update_user(id::AbstractString, first_name::Optional{AbstractString}, last_name::Optional{AbstractString}, password::Optional{AbstractString}, is_admin::Optional{Bool})::Type{<:UpsertResult}

Update an [`User`](@ref).

# Arguments
- `id::AbstractString`: The id of the user to update.
- `first_name::Optional{AbstractString}`: The new first name of the user.
- `last_name::Optional{AbstractString}`: The new last name of the user.
- `password::Optional{AbstractString}`: The new password of the user.
- `is_admin::Optional{Bool}`: The new admin status of the user.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no fields were changed), [`Unprocessable`](@ref) if the record violates a constraint or if no fields were provided to update, and [`Error`](@ref) if an error occurred while updating the record.
"""
function update_user(
    id::AbstractString,
    first_name::Optional{AbstractString},
    last_name::Optional{AbstractString},
    password::Optional{AbstractString},
    is_admin::Optional{Bool},
)::Type{<:UpsertResult}
    user = fetch(User, id)
    if isnothing(user)
        return Unprocessable
    end

    # The seeded `default` user must stay an admin (previously a DB trigger; now enforced
    # here since DuckDB has no triggers).
    if user.username == "default" && is_admin === false
        return Unprocessable
    end

    should_be_updated = compare_object_fields(
        user;
        first_name=first_name,
        last_name=last_name,
        password=password,
        is_admin=is_admin,
    )
    if !should_be_updated
        return Updated
    end

    if !(isnothing(password))
        hashed_password = String(GenerateFromPassword(password))
    end
    return update(
        User,
        id;
        first_name=first_name,
        last_name=last_name,
        password=(isnothing(password)) ? nothing : hashed_password,
        is_admin=is_admin,
    )
end

"""
    delete_user(id::AbstractString)::Bool

Delete an [`User`](@ref). Also deletes all associated [`UserPermission`](@ref).

# Arguments
- `id::AbstractString`: The id of the user to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_user(id::AbstractString)::Bool
    user = fetch(User, id)
    # The seeded `default` user is protected (previously enforced by a DB trigger; DuckDB has
    # no triggers, so the guard lives here).
    if !(user isa User) || user.username == "default"
        return false
    end

    delete(UserPermission, user)
    return delete(User, id)
end

"""
    sanitize_user(user::User)::UserResponse
    sanitize_user(users::AbstractArray{User,1})::Array{UserResponse,1}
    sanitize_user(::Nothing)::Nothing

Project a [`User`](@ref) (or array of them) into a [`UserResponse`](@ref) that omits the
password hash, suitable for serializing in API responses.
"""
function sanitize_user(user::User)::UserResponse
    return UserResponse(
        user.id,
        user.first_name,
        user.last_name,
        user.username,
        user.created_date,
        user.is_admin,
    )
end
sanitize_user(users::AbstractArray{User,1})::Array{UserResponse,1} = sanitize_user.(users)
sanitize_user(::Nothing)::Nothing = nothing
