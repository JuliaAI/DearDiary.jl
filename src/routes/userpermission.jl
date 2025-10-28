"""
    get_userpermission_by_user_and_project_handler(request::HTTP.Request, user_id::Int,
        project_id::Int)::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
@admin_required function get_userpermission_by_user_and_project_handler(request::HTTP.Request,
    user_id::Int, project_id::Int)::HTTP.Response
    response_userpermission = get_userpermission_by_user_and_project(user_id, project_id)

    if (response_userpermission |> isnothing)
        return json(("message" => (HTTP.StatusCodes.NOT_FOUND |> HTTP.statustext));
            status=HTTP.StatusCodes.NOT_FOUND)
    end
    return json(response_userpermission; status=HTTP.StatusCodes.OK)
end

"""
    create_userpermission_handler(request::HTTP.Request, user_id::Int,
        project_id::Int, parameters::Json{UserPermissionCreatePayload})::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
@admin_required function create_userpermission_handler(request::HTTP.Request, user_id::Int,
    project_id::Int, parameters::Json{UserPermissionCreatePayload})::HTTP.Response
    userpermission_id, upsert_result = create_userpermission(user_id, project_id,
        parameters.payload)
    upsert_status = upsert_result |> get_status_by_upsert_result
    return json(("userpermission_id" => userpermission_id); status=upsert_status)
end

"""
    update_userpermission_handler(request::HTTP.Request, id::Int,
        parameters::Json{UserPermissionUpdatePayload})::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
@admin_required function update_userpermission_handler(request::HTTP.Request,
    id::Int, parameters::Json{UserPermissionUpdatePayload})::HTTP.Response
    upsert_result = update_userpermission(id, parameters.payload)
    upsert_status = upsert_result |> get_status_by_upsert_result
    return json(("message" => (upsert_result |> String)); status=upsert_status)
end

"""
    delete_userpermission_handler(request::HTTP.Request, id::Int)::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
@admin_required function delete_userpermission_handler(request::HTTP.Request,
    id::Int)::HTTP.Response
    success = id |> delete_userpermission

    if !success
        return json(("message" => (HTTP.StatusCodes.INTERNAL_SERVER_ERROR |> HTTP.statustext));
            status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR)
    end
    return json(("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
        status=HTTP.StatusCodes.OK)
end
