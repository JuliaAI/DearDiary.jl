"""
    setup_userpermission_routes()

This function sets up the userpermission-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_userpermission_routes()
    root = router("/userpermission", tags=["userpermission"])

    @get root("/user/{user_id}/project/{project_id}") @admin_required function (
        request::HTTP.Request, user_id::Integer, project_id::Integer
    )
        response_userpermission = get_userpermission_by_user_and_project(
            user_id,
            project_id,
        )

        if (response_userpermission |> isnothing)
            return json(
                ("message" => (HTTP.StatusCodes.NOT_FOUND |> HTTP.statustext));
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_userpermission; status=HTTP.StatusCodes.OK)
    end

    @post root("/user/{user_id}/project/{project_id}") @admin_required function (
        request::HTTP.Request,
        user_id::Integer,
        project_id::Integer,
        parameters::Json{UserPermissionCreatePayload},
    )
        userpermission_id, upsert_result = create_userpermission(
            user_id,
            project_id,
            parameters.payload.create_permission,
            parameters.payload.read_permission,
            parameters.payload.update_permission,
            parameters.payload.delete_permission,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("userpermission_id" => userpermission_id); status=upsert_status)
    end

    @patch root("/{id}") @admin_required function (
        request::HTTP.Request, id::Integer, parameters::Json{UserPermissionUpdatePayload}
    )
        upsert_result = update_userpermission(
            id,
            parameters.payload.create_permission,
            parameters.payload.read_permission,
            parameters.payload.update_permission,
            parameters.payload.delete_permission,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("message" => (upsert_result |> String)); status=upsert_status)
    end

    @delete root("/{id}") @admin_required function (request::HTTP.Request, id::Integer)
        success = id |> delete_userpermission

        if !success
            return json(
                ("message" => (HTTP.StatusCodes.INTERNAL_SERVER_ERROR |> HTTP.statustext));
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
