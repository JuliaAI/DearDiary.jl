"""
    setup_user_routes()

Register user routes (`/user`). Internal use only.
"""
function setup_user_routes()
    root = router("/user"; tags=["user"])

    @get root("/{id}", middleware=[SameUserOrAdminRequiredMiddleware]) function (
        ::HTTP.Request, id::String
    )
        response_user = get_user(id)

        if (isnothing(response_user))
            return error_response(
                UserNotFound, "User not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(sanitize_user(response_user); status=HTTP.StatusCodes.OK)
    end

    @get root("/", middleware=[AdminRequiredMiddleware]) function (::HTTP.Request)
        return json(sanitize_user(get_users()); status=HTTP.StatusCodes.OK)
    end

    @get root("/{id}/permissions", middleware=[SameUserOrAdminRequiredMiddleware]) function (
        ::HTTP.Request, id::String
    )
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
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("user_id" => user_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root("/{id}", middleware=[SameUserOrAdminRequiredMiddleware]) function (
        request::HTTP.Request, id::String, parameters::Json{UserUpdatePayload}
    )
        # `is_admin` is a privilege boundary: only an admin may change it. A non-admin
        # reaches this handler solely for their own id (SameUserOrAdminRequiredMiddleware),
        # so without this guard they could self-promote by patching their own record.
        requester = request.context[:user]
        if !(isnothing(parameters.payload.is_admin)) && !requester.is_admin
            return error_response(
                AdminRequired,
                "Admin privileges required to change admin status";
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
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[SameUserOrAdminRequiredMiddleware]) function (
        ::HTTP.Request, id::String
    )
        success = delete_user(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete user";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
