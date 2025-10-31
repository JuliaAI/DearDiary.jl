function fetch(::Type{<:User}, username::AbstractString)::Optional{User}
    user = fetch(SQL_SELECT_USER_BY_USERNAME, (username=username,))
    return (user |> isnothing) ? nothing : (user |> User)
end

function fetch(::Type{<:User}, id::Integer)::Optional{User}
    user = fetch(SQL_SELECT_USER_BY_ID, (id=id,))
    return (user |> isnothing) ? nothing : (user |> User)
end

fetch_all(::Type{<:User})::Array{User,1} = SQL_SELECT_USERS |> fetch_all .|> User

function fetch_all(::Type{<:User}, project_id::Integer)::Array{User,1}
    return fetch_all(SQL_SELECT_USERS_BY_PROJECT_ID, (id=project_id,)) .|> User
end

function insert(
    ::Type{<:User},
    first_name::AbstractString,
    last_name::AbstractString,
    username::AbstractString,
    password::AbstractString,
)::Tuple{Optional{<:Int64},UpsertResult}
    fields = (
        first_name=first_name,
        last_name=last_name,
        username=username,
        password=password,
        created_date=(now() |> string),
    )
    return insert(SQL_INSERT_USER, fields)
end

function update(
    ::Type{<:User}, id::Integer;
    first_name::Optional{AbstractString}=nothing,
    last_name::Optional{AbstractString}=nothing,
    password::Optional{AbstractString}=nothing,
    is_admin::Optional{Bool}=nothing,
)::UpsertResult
    fields = (
        first_name=first_name,
        last_name=last_name,
        password=password,
        is_admin=is_admin,
    )
    return update(SQL_UPDATE_USER, fetch(User, id); fields...)
end

delete(::Type{<:User}, id::Integer)::Bool = delete(SQL_DELETE_USER, id)
