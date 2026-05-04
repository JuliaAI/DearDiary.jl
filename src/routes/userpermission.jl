"""
    setup_userpermission_routes()

This function sets up the userpermission-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_userpermission_routes()
    root = router(
        "/userpermission",
        tags=["userpermission"],
        middleware=[AdminRequiredMiddleware],
    )

    @get root("/user/{user_id}/project/{project_id}") function (
        ::HTTP.Request, user_id::Integer, project_id::Integer
    )
        response_userpermission = get_userpermission(user_id, project_id)

        if (response_userpermission |> isnothing)
            return error_response(
                NotFound, "User permission not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_userpermission; status=HTTP.StatusCodes.OK)
    end

    @post root("/user/{user_id}/project/{project_id}") function (
        ::HTTP.Request,
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
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create user permission";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(
            ("userpermission_id" => userpermission_id);
            status=HTTP.StatusCodes.CREATED,
        )
    end

    @patch root("/{id}") function (
        ::HTTP.Request, id::Integer, parameters::Json{UserPermissionUpdatePayload}
    )
        upsert_result = update_userpermission(
            id,
            parameters.payload.create_permission,
            parameters.payload.read_permission,
            parameters.payload.update_permission,
            parameters.payload.delete_permission,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update user permission";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("message" => (upsert_result |> String)); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}") function (::HTTP.Request, id::Integer)
        success = id |> delete_userpermission

        if !success
            return error_response(
                ServerError, "Failed to delete user permission";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
