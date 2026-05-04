"""
    setup_parameter_routes()

This function sets up the parameter-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_parameter_routes()
    root = router("/parameter", tags=["parameter"])

    @get root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Parameter, ReadPermission),
    ]) function (::HTTP.Request, id::Integer)
        response_parameter = id |> get_parameter

        if (response_parameter |> isnothing)
            return error_response(
                NotFound, "Parameter not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_parameter; status=HTTP.StatusCodes.OK)
    end

    @get root("/iteration/{iteration_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Parameter, ReadPermission),
    ]) function (request::HTTP.Request, iteration_id::Integer)
        page = request |> parse_pagination
        return json(get_parameters(iteration_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root("/iteration/{iteration_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Parameter, CreatePermission),
    ]) function (
        ::HTTP.Request,
        iteration_id::Integer,
        parameters::Json{ParameterCreatePayload},
    )
        parameter_id, upsert_result = create_parameter(
            iteration_id,
            parameters.payload.key,
            parameters.payload.value,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create parameter";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("parameter_id" => parameter_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Parameter, UpdatePermission),
    ]) function (
        ::HTTP.Request, id::Integer, parameters::Json{ParameterUpdatePayload}
    )
        upsert_result = update_parameter(
            id,
            parameters.payload.key,
            parameters.payload.value,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update parameter";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("message" => (upsert_result |> String)); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Parameter, DeletePermission),
    ]) function (::HTTP.Request, id::Integer)
        success = id |> delete_parameter

        if !success
            return error_response(
                ServerError, "Failed to delete parameter";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
