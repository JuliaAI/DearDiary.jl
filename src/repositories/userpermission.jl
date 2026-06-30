function fetch(::Type{<:UserPermission}, id::AbstractString)::Optional{UserPermission}
    user_permission = fetch(SQL_SELECT_USERPERMISSION_BY_ID, (id=id,))
    return (isnothing(user_permission)) ? nothing : (UserPermission(user_permission))
end

function fetch(
    ::Type{<:UserPermission}, user_id::AbstractString, project_id::AbstractString
)::Optional{UserPermission}
    user_permission = fetch(
        SQL_SELECT_USERPERMISSION_BY_USERID_AND_PROJECT_ID,
        (user_id=user_id, project_id=project_id),
    )
    return (isnothing(user_permission)) ? nothing : (UserPermission(user_permission))
end

function fetch_all(
    ::Type{<:UserPermission}, ::Type{<:Project}, project_id::AbstractString
)::Array{UserPermission,1}
    rows = fetch_all(SQL_SELECT_USERPERMISSIONS_BY_PROJECT_ID; parameters=(id=project_id,))
    return UserPermission.(rows)
end

function fetch_all(
    ::Type{<:UserPermission}, ::Type{<:User}, user_id::AbstractString
)::Array{UserPermission,1}
    rows = fetch_all(SQL_SELECT_USERPERMISSIONS_BY_USER_ID; parameters=(id=user_id,))
    return UserPermission.(rows)
end

function insert(
    ::Type{<:UserPermission}, user_id::AbstractString, project_id::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    return insert(SQL_INSERT_USERPERMISSION, (user_id=user_id, project_id=project_id))
end

function update(
    ::Type{<:UserPermission},
    id::AbstractString;
    create_permission::Optional{Bool}=nothing,
    read_permission::Optional{Bool}=nothing,
    update_permission::Optional{Bool}=nothing,
    delete_permission::Optional{Bool}=nothing,
    manage_permission::Optional{Bool}=nothing,
)::Type{<:UpsertResult}
    fields = (
        create_permission=create_permission,
        read_permission=read_permission,
        update_permission=update_permission,
        delete_permission=delete_permission,
        manage_permission=manage_permission,
    )
    return update(SQL_UPDATE_USERPERMISSION, fetch(UserPermission, id); fields...)
end

delete(::Type{<:UserPermission}, id::AbstractString)::Bool = delete(
    SQL_DELETE_USERPERMISSION, id
)

function delete(::Type{<:UserPermission}, user::User)::Bool
    return delete(SQL_DELETE_USERPERMISSIONS_BY_USER_ID, user.id)
end

function delete(::Type{<:UserPermission}, project::Project)::Bool
    return delete(SQL_DELETE_USERPERMISSIONS_BY_PROJECT_ID, project.id)
end
