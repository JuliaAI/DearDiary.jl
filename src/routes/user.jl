"""
    setup_user_routes()

This function sets up the user-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_user_routes()
    root = router("/user", tags=["user"])

    @get root("/{id}") @same_user_or_admin_required function (
        request::HTTP.Request, id::Integer
    )
        response_user = id |> get_user_by_id

        if (response_user |> isnothing)
            return json(
                ("message" => (HTTP.StatusCodes.NOT_FOUND |> HTTP.statustext));
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_user; status=HTTP.StatusCodes.OK)
    end

    @get root("/") @admin_required function (request::HTTP.Request)
        return json(get_users(); status=HTTP.StatusCodes.OK)
    end

    @post root("/") @admin_required function (
        request::HTTP.Request, parameters::Json{UserCreatePayload}
    )
        user_id, upsert_result = create_user(
            parameters.payload.first_name,
            parameters.payload.last_name,
            parameters.payload.username,
            parameters.payload.password,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("user_id" => user_id); status=upsert_status)
    end

    @patch root("/{id}") @same_user_or_admin_required function (
        request::HTTP.Request, id::Integer, parameters::Json{UserUpdatePayload}
    )
        upsert_result = update_user(
            id,
            parameters.payload.first_name,
            parameters.payload.last_name,
            parameters.payload.password,
            parameters.payload.is_admin,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("message" => (upsert_result |> String)); status=upsert_status)
    end

    @delete root("/{id}") @same_user_or_admin_required function (
        request::HTTP.Request, id::Integer
    )
        success = id |> delete_user

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
