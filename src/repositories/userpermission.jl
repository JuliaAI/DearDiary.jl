function fetch(::Type{<:UserPermission}, id::Integer)::Optional{UserPermission}
    user_permission = fetch(SQL_SELECT_USERPERMISSION_BY_ID, (id=id,))
    return (user_permission |> isnothing) ? nothing : (user_permission |> UserPermission)
end

function fetch(
    ::Type{<:UserPermission}, user_id::Integer, project_id::Integer
)::Optional{UserPermission}
    user_permission = fetch(
        SQL_SELECT_USERPERMISSION_BY_USERID_AND_PROJECT_ID,
        (user_id=user_id, project_id=project_id,),
    )
    return (user_permission |> isnothing) ? nothing : (user_permission |> UserPermission)
end

function insert(
    ::Type{<:UserPermission}, user_id::Integer, project_id::Integer
)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
    return insert(SQL_INSERT_USERPERMISSION, (user_id=user_id, project_id=project_id))
end

function update(
    ::Type{<:UserPermission}, id::Integer;
    create_permission::Optional{Bool}=nothing,
    read_permission::Optional{Bool}=nothing,
    update_permission::Optional{Bool}=nothing,
    delete_permission::Optional{Bool}=nothing,
    manage_permission::Optional{Bool}=nothing,
)::UpsertResult
    fields = (
        create_permission=create_permission,
        read_permission=read_permission,
        update_permission=update_permission,
        delete_permission=delete_permission,
        manage_permission=manage_permission,
    )
    return update(SQL_UPDATE_USERPERMISSION, fetch(UserPermission, id); fields...)
end

delete(::Type{<:UserPermission}, id::Integer)::Bool = delete(SQL_DELETE_USERPERMISSION, id)

function delete(::Type{<:UserPermission}, user::User)::Bool
    return delete(SQL_DELETE_USERPERMISSIONS_BY_USER_ID, user.id)
end

function delete(::Type{<:UserPermission}, project::Project)::Bool
    return delete(SQL_DELETE_USERPERMISSIONS_BY_PROJECT_ID, project.id)
end
