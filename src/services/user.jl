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
    create_user(user_payload::UserCreatePayload)::UpsertResult

Create an [`User`](@ref).

# Arguments
- `user_payload::UserCreatePayload`: The payload for creating an user.

# Returns
An [`UpsertResult`](@ref). `CREATED` if the record was successfully created, `DUPLICATE` if
the record already exists, `UNPROCESSABLE` if the record violates a constraint, and `ERROR`
if an error occurred while creating the record.
"""
function create_user(user_payload::UserCreatePayload)::UpsertResult
    hashed_password = GenerateFromPassword(user_payload.password) |> String
    return insert(User, user_payload.first_name, user_payload.last_name,
        user_payload.username, hashed_password)
end

"""
    update_user(id::Int; first_name::Union{String,Nothing}=nothing,
        last_name::Union{String,Nothing}=nothing,
        password::Union{String,Nothing}=nothing)::UpsertResult

Update an [`User`](@ref).

# Arguments
- `id::Int`: The id of the user to update.

# Keyword Arguments
- `first_name::Union{String,Nothing}`: The first name of the user.
- `last_name::Union{String,Nothing}`: The last name of the user.
- `password::Union{String,Nothing}`: The password of the user. This will be hashed
    before updating the user.

# Returns
An [`UpsertResult`](@ref). `UPDATED` if the record was successfully updated,
`UNPROCESSABLE` if the record violates a constraint or if no fields were provided to
update, and `ERROR` if an error occurred while updating the record.
"""
function update_user(id::Int, user_payload::UserUpdatePayload)::UpsertResult
    user = fetch(User, id)
    if user |> isnothing || (user_payload.first_name |> isnothing && user_payload.last_name |> isnothing && user_payload.password |> isnothing)
        return UpsertResult.UNPROCESSABLE
    end

    should_be_updated = compare_object_fields(user; first_name=user_payload.first_name,
        last_name=user_payload.last_name, password=user_payload.password)
    if !should_be_updated
        return UpsertResult.UNPROCESSABLE
    end

    if !(user_payload.password |> isnothing)
        hashed_password = GenerateFromPassword(user_payload.password) |> String
    end
    return update(User, id; first_name=user_payload.first_name,
        last_name=user_payload.last_name,
        password=(user_payload.password |> isnothing) ? nothing : hashed_password)
end
