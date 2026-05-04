"""
    setup_iteration_routes()

This function sets up the iteration-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_iteration_routes()
    root = router("/iteration", tags=["iteration"])

    @get root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Iteration, ReadPermission),
    ]) function (::HTTP.Request, id::Integer)
        response_iteration = id |> get_iteration

        if (response_iteration |> isnothing)
            return error_response(
                NotFound, "Iteration not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_iteration; status=HTTP.StatusCodes.OK)
    end

    @get root("/experiment/{experiment_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Iteration, ReadPermission),
    ]) function (request::HTTP.Request, experiment_id::Integer)
        page = request |> parse_pagination
        return json(get_iterations(experiment_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root("/experiment/{experiment_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Iteration, CreatePermission),
    ]) function (::HTTP.Request, experiment_id::Integer)
        iteration_id, upsert_result = experiment_id |> create_iteration
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create iteration";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("iteration_id" => iteration_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Iteration, UpdatePermission),
    ]) function (
        ::HTTP.Request, id::Integer, parameters::Json{IterationUpdatePayload}
    )
        upsert_result = update_iteration(
            id,
            parameters.payload.notes,
            parameters.payload.end_date,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update iteration";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("message" => (upsert_result |> String)); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Iteration, DeletePermission),
    ]) function (::HTTP.Request, id::Integer)
        success = id |> delete_iteration

        if !success
            return error_response(
                ServerError, "Failed to delete iteration";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
