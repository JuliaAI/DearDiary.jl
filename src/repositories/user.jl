function fetch(::Type{<:User}, username::AbstractString)::Optional{User}
    user = fetch(SQL_SELECT_USER_BY_USERNAME, (username=username,))
    return (isnothing(user)) ? nothing : (User(user))
end

function fetch(::Type{<:User}, id::Integer)::Optional{User}
    user = fetch(SQL_SELECT_USER_BY_ID, (id=id,))
    return (isnothing(user)) ? nothing : (User(user))
end

fetch_all(::Type{<:User})::Array{User,1} = User.(fetch_all(SQL_SELECT_USERS))

function insert(
    ::Type{<:User},
    first_name::AbstractString,
    last_name::AbstractString,
    username::AbstractString,
    password::AbstractString,
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    fields = (
        first_name=first_name,
        last_name=last_name,
        username=username,
        password=password,
        created_date=(string(now())),
    )
    return insert(SQL_INSERT_USER, fields)
end

function update(
    ::Type{<:User},
    id::Integer;
    first_name::Optional{AbstractString}=nothing,
    last_name::Optional{AbstractString}=nothing,
    password::Optional{AbstractString}=nothing,
    is_admin::Optional{Bool}=nothing,
)::Type{<:UpsertResult}
    fields = (
        first_name=first_name, last_name=last_name, password=password, is_admin=is_admin
    )
    return update(SQL_UPDATE_USER, fetch(User, id); fields...)
end

delete(::Type{<:User}, id::Integer)::Bool = delete(SQL_DELETE_USER, id)
