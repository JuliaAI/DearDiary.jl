"""
    get_userpermission(client::Client, user_id::AbstractString, project_id::AbstractString)::Optional{UserPermission}

Fetch the [`UserPermission`](@ref) row tying `user_id` to `project_id` via
`GET /userpermission/user/{user_id}/project/{project_id}`. Returns `nothing` when the
server replies 404 and raises [`ClientError`](@ref) for other failures. Admin-only route.
"""
function get_userpermission(
    client::Client, user_id::AbstractString, project_id::AbstractString
)::Optional{UserPermission}
    try
        decoded = _json(
            _request(client, "GET", "/userpermission/user/$user_id/project/$project_id")
        )
        return UserPermission(decoded)
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_userpermissions(client::Client, ::Type{User}, user_id::AbstractString)::Array{UserPermission,1}

List every [`UserPermission`](@ref) that grants `user_id` access to some project, via
`GET /user/{user_id}/permissions`. The viewer must be `user_id` or an admin.
"""
function get_userpermissions(
    client::Client, ::Type{User}, user_id::AbstractString
)::Array{UserPermission,1}
    response = _request(client, "GET", "/user/$user_id/permissions")
    decoded = JSON.parse(String(response.body))
    return [UserPermission(item) for item in decoded]
end

"""
    get_userpermissions(client::Client, ::Type{Project}, project_id::AbstractString)::Array{UserPermission,1}

List every [`UserPermission`](@ref) row granting access to `project_id`, via
`GET /project/{project_id}/members`. Requires [`ReadPermission`](@ref) on the project.
"""
function get_userpermissions(
    client::Client, ::Type{Project}, project_id::AbstractString
)::Array{UserPermission,1}
    response = _request(client, "GET", "/project/$project_id/members")
    decoded = JSON.parse(String(response.body))
    return [UserPermission(item) for item in decoded]
end

"""
    create_userpermission(client::Client, user_id, project_id, create, read, update, delete)::String

Insert a [`UserPermission`](@ref) row via
`POST /userpermission/user/{user_id}/project/{project_id}`. Admin-only. Returns the new
permission id.
"""
function create_userpermission(
    client::Client,
    user_id::AbstractString,
    project_id::AbstractString,
    create_permission::Bool,
    read_permission::Bool,
    update_permission::Bool,
    delete_permission::Bool,
)::String
    response = _request(
        client,
        "POST",
        "/userpermission/user/$user_id/project/$project_id";
        body=Dict(
            "create_permission" => create_permission,
            "read_permission" => read_permission,
            "update_permission" => update_permission,
            "delete_permission" => delete_permission,
        ),
    )
    return _json(response)["userpermission_id"]
end

"""
    update_userpermission(client::Client, id::AbstractString; create_permission=nothing, read_permission=nothing, update_permission=nothing, delete_permission=nothing)::Nothing

Patch a [`UserPermission`](@ref) row via `PATCH /userpermission/{id}`. Any keyword left as
`nothing` is left untouched server-side. Admin-only.
"""
function update_userpermission(
    client::Client,
    id::AbstractString;
    create_permission::Optional{Bool}=nothing,
    read_permission::Optional{Bool}=nothing,
    update_permission::Optional{Bool}=nothing,
    delete_permission::Optional{Bool}=nothing,
)::Nothing
    _request(
        client,
        "PATCH",
        "/userpermission/$id";
        body=Dict(
            "create_permission" => create_permission,
            "read_permission" => read_permission,
            "update_permission" => update_permission,
            "delete_permission" => delete_permission,
        ),
    )
    return nothing
end

"""
    delete_userpermission(client::Client, id::AbstractString)::Nothing

Delete a [`UserPermission`](@ref) row via `DELETE /userpermission/{id}`. Admin-only.
Raises [`ClientError`](@ref) on failure.
"""
function delete_userpermission(client::Client, id::AbstractString)::Nothing
    _request(client, "DELETE", "/userpermission/$id")
    return nothing
end
