"""
    get_user_by_username(username::AbstractString)::Union{User, Nothing}

Get an [`User`](@ref) by username.

# Arguments
- `username::AbstractString`: The username of the user to query.

# Returns
An [`User`](@ref) object. If the record does not exist, return `nothing`.
"""
get_user_by_username(username::AbstractString)::Union{User,Nothing} = fetch(User, username)

"""
    get_user_by_id(id::Integer)::Union{User, Nothing}

Get an [`User`](@ref) by id.

# Arguments
- `id::Integer`: The id of the user to query.

# Returns
An [`User`](@ref) object. If the record does not exist, return `nothing`.
"""
get_user_by_id(id::Integer)::Union{User,Nothing} = fetch(User, id)

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
    create_user(user_payload::UserCreatePayload)::Tuple{Union{Nothing,<:Integer},UpsertResult}

Create an [`User`](@ref).

# Arguments
- `user_payload::UserCreatePayload`: The payload for creating an user.

# Returns
An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created,
[`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record
violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_user(user_payload::UserCreatePayload)::Tuple{Union{Nothing,<:Integer},UpsertResult}
    hashed_password = GenerateFromPassword(user_payload.password) |> String
    return insert(User, user_payload.first_name, user_payload.last_name,
        user_payload.username, hashed_password)
end

"""
    update_user(id::Int, user_payload::UserUpdatePayload)::UpsertResult

Update an [`User`](@ref).

# Arguments
- `id::Int`: The id of the user to update.
- `user_payload::UserUpdatePayload`: The payload for updating an user.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or
no fields were changed), [`Unprocessable`](@ref) if the record violates a constraint or if
no fields were provided to update, and [`Error`](@ref) if an error occurred while updating
the record.
"""
function update_user(id::Int, user_payload::UserUpdatePayload)::UpsertResult
    user = fetch(User, id)
    if user |> isnothing || (user_payload.first_name |> isnothing && user_payload.last_name |> isnothing && user_payload.password |> isnothing)
        return Unprocessable()
    end

    should_be_updated = compare_object_fields(user; first_name=user_payload.first_name,
        last_name=user_payload.last_name, password=user_payload.password)
    if !should_be_updated
        return Updated()
    end

    if !(user_payload.password |> isnothing)
        hashed_password = GenerateFromPassword(user_payload.password) |> String
    end
    return update(User, id; first_name=user_payload.first_name,
        last_name=user_payload.last_name,
        password=(user_payload.password |> isnothing) ? nothing : hashed_password,
        is_admin=user_payload.is_admin)
end

"""
    delete_user(id::Int)::Bool

Delete an [`User`](@ref). Also deletes all associated [`UserPermission`](@ref).

# Arguments
- `id::Int`: The id of the user to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_user(id::Int)::Bool
    user = fetch(User, id)

    delete(UserPermission, user)
    return delete(User, id)
end
