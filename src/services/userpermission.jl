"""
    get_userpermission_by_user_and_project(user_id::Integer,
        project_id::Integer)::Union{UserPermission, Nothing}

Get a [`UserPermission`](@ref) by [`User`](@ref) id and [`Project`](@ref) IDs.

# Arguments
- `user_id::Integer`: The id of the user.
- `project_id::Integer`: The id of the project.

# Returns
A [`UserPermission`](@ref) object. If the record does not exist, return `nothing`.
"""
get_userpermission_by_user_and_project(user_id::Integer,
    project_id::Integer)::Union{UserPermission,Nothing} =
    fetch(UserPermission, user_id, project_id)

function create_userpermission(user_id::Integer, project_id::Integer,
    userpermission_payload::UserPermissionCreatePayload)::Tuple{Union{Nothing,<:Integer},UpsertResult}
    user = user_id |> get_user_by_id
    if user |> isnothing || user.is_admin == 0
        return nothing, Unprocessable()
    end

    project = project_id |> get_project_by_id
    if project |> isnothing
        return nothing, Unprocessable()
    end

end
