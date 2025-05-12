"""
    fetch(::Type{<:User}, username::String)::Union{User, Nothing}

Fetch an [`User`](@ref) record by username.

# Arguments
- `::Type{<:User}`: The type of the record to query.
- `username::String`: The username of the user to query.

# Returns
An [`User`](@ref) object. If the record does not exist, return `nothing`.
"""
function fetch(::Type{<:User}, username::String)::Union{User,Nothing}
    user = fetch(SQL_SELECT_USER_BY_USERNAME, (username=username,))
    return (user |> isnothing) ? nothing : (user |> User)
end

"""
    fetch(::Type{<:User}, id::Integer)::Union{User, Nothing}

Fetch an [`User`](@ref) record by id.

# Arguments
- `::Type{<:User}`: The type of the record to query.
- `id::Integer`: The id of the user to query.

# Returns
An [`User`](@ref) object. If the record does not exist, return `nothing`.
"""
function fetch(::Type{<:User}, id::Integer)::Union{User,Nothing}
    user = fetch(SQL_SELECT_USER_BY_ID, (id=id,))
    return (user |> isnothing) ? nothing : (user |> User)
end

"""
    fetch_all(::Type{<:User})::Array{User,1}

Fetch all [`User`](@ref) records.

# Arguments
- `::Type{<:User}`: The type of the records to fetch.

# Returns
An array of [`User`](@ref) objects.
"""
fetch_all(::Type{<:User})::Array{User,1} = SQL_SELECT_USERS |> fetch_all .|> User

"""
    insert_record(::Type{<:User}, first_name::String, last_name::String, username::String,
        password::String)::UpsertResult

Insert an [`User`](@ref) record.

# Arguments
- `::Type{<:User}`: The type of the record to insert.
- `first_name::String`: The first name of the user.
- `last_name::String`: The last name of the user.
- `username::String`: The username of the user.
- `password::String`: The password of the user.

# Returns
An [`UpsertResult`](@ref). `CREATED` if the record was successfully created, `DUPLICATE` if
the record already exists, `UNPROCESSABLE` if the record violates a constraint, and `ERROR`
if an error occurred while creating the record.
"""
insert(::Type{<:User}, first_name::String, last_name::String, username::String,
    password::String)::UpsertResult =
    insert(SQL_INSERT_USER, (first_name=first_name, last_name=last_name, username=username,
        password=password, created_at=(now() |> string),))

"""
    update(::Type{<:User}, first_name::String, last_name::String, username::String,
        password::String)::UpsertResult

Update an [`User`](@ref) record.

# Arguments
- `::Type{<:User}`: The type of the record to update.
- `first_name::String`: The first name of the user.
- `last_name::String`: The last name of the user.
- `password::String`: The password of the user.

# Returns
An [`UpsertResult`](@ref). `UPDATED` if the record was successfully updated,
`UNPROCESSABLE` if the record violates a constraint, and `ERROR` if an error occurred.
"""
update(::Type{<:User}, id::Integer; first_name::Union{String,Nothing}=nothing,
    last_name::Union{String,Nothing}=nothing,
    password::Union{String,Nothing}=nothing)::UpsertResult =
    update(SQL_UPDATE_USER, fetch(User, id); first_name=first_name, last_name=last_name,
        password=password)
