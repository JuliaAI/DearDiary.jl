"""
    setup_userpermission_routes()

Register user-permission routes (`/userpermission`). Internal use only.
"""
function setup_userpermission_routes()
    root = router(
        "/userpermission"; tags=["userpermission"], middleware=[AdminRequiredMiddleware]
    )

    @get root("/user/{user_id}/project/{project_id}") function (
        ::HTTP.Request, user_id::String, project_id::String
    )
        response_userpermission = get_userpermission(user_id, project_id)

        if (isnothing(response_userpermission))
            return error_response(
                NotFound, "User permission not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(response_userpermission; status=HTTP.StatusCodes.OK)
    end

    @post root("/user/{user_id}/project/{project_id}") function (
        ::HTTP.Request,
        user_id::String,
        project_id::String,
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
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(
            ("userpermission_id" => userpermission_id); status=HTTP.StatusCodes.CREATED
        )
    end

    @patch root("/{id}") function (
        ::HTTP.Request, id::String, parameters::Json{UserPermissionUpdatePayload}
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
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}") function (::HTTP.Request, id::String)
        success = delete_userpermission(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete user permission";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
