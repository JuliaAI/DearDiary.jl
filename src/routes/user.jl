"""
    setup_user_routes()

This function sets up the user-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_user_routes()
    root = router("/user", tags=["user"])

    @get root("/{id}", middleware=[SameUserOrAdminRequiredMiddleware]) function (
        ::HTTP.Request, id::Integer
    )
        response_user = id |> get_user

        if (response_user |> isnothing)
            return error_response(
                UserNotFound, "User not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_user |> sanitize_user; status=HTTP.StatusCodes.OK)
    end

    @get root("/", middleware=[AdminRequiredMiddleware]) function (::HTTP.Request)
        return json(get_users() |> sanitize_user; status=HTTP.StatusCodes.OK)
    end

    @get root("/{id}/permissions", middleware=[
        SameUserOrAdminRequiredMiddleware,
    ]) function (::HTTP.Request, id::Integer)
        return json(get_userpermissions(User, id); status=HTTP.StatusCodes.OK)
    end

    @post root("/", middleware=[AdminRequiredMiddleware]) function (
        ::HTTP.Request, parameters::Json{UserCreatePayload}
    )
        user_id, upsert_result = create_user(
            parameters.payload.first_name,
            parameters.payload.last_name,
            parameters.payload.username,
            parameters.payload.password,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create user";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("user_id" => user_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root("/{id}", middleware=[SameUserOrAdminRequiredMiddleware]) function (
        request::HTTP.Request, id::Integer, parameters::Json{UserUpdatePayload}
    )
        # `is_admin` is a privilege boundary: only an admin may change it. A non-admin
        # reaches this handler solely for their own id (SameUserOrAdminRequiredMiddleware),
        # so without this guard they could self-promote by patching their own record.
        requester = request.context[:user]
        if !(parameters.payload.is_admin |> isnothing) && !requester.is_admin
            return error_response(
                AdminRequired, "Admin privileges required to change admin status";
                status=HTTP.StatusCodes.FORBIDDEN,
            )
        end

        upsert_result = update_user(
            id,
            parameters.payload.first_name,
            parameters.payload.last_name,
            parameters.payload.password,
            parameters.payload.is_admin,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update user";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("message" => (upsert_result |> String)); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[SameUserOrAdminRequiredMiddleware]) function (
        ::HTTP.Request, id::Integer
    )
        success = id |> delete_user

        if !success
            return error_response(
                ServerError, "Failed to delete user";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
