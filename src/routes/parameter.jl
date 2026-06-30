"""
    setup_parameter_routes()

Register parameter routes (`/parameter`). Internal use only.
"""
function setup_parameter_routes()
    root = router("/parameter"; tags=["parameter"])

    @get root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Parameter, ReadPermission)]
    ) function (::HTTP.Request, id::String)
        response_parameter = get_parameter(id)

        if (isnothing(response_parameter))
            return error_response(
                NotFound, "Parameter not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(response_parameter; status=HTTP.StatusCodes.OK)
    end

    @get root(
        "/iteration/{iteration_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Parameter, ReadPermission)],
    ) function (request::HTTP.Request, iteration_id::String)
        page = parse_pagination(request)
        return json(get_parameters(iteration_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root(
        "/iteration/{iteration_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Parameter, CreatePermission)],
    ) function (
        ::HTTP.Request, iteration_id::String, parameters::Json{ParameterCreatePayload}
    )
        parameter_id, upsert_result = create_parameter(
            iteration_id, parameters.payload.key, parameters.payload.value
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create parameter";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("parameter_id" => parameter_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(Parameter, UpdatePermission)],
    ) function (::HTTP.Request, id::String, parameters::Json{ParameterUpdatePayload})
        upsert_result = update_parameter(
            id, parameters.payload.key, parameters.payload.value
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update parameter";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(Parameter, DeletePermission)],
    ) function (::HTTP.Request, id::String)
        success = delete_parameter(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete parameter";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
