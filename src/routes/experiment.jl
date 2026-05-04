"""
    setup_experiment_routes()

This function sets up the experiment-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_experiment_routes()
    root = router("/experiment", tags=["experiment"])

    @get root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Experiment, ReadPermission),
    ]) function (::HTTP.Request, id::Integer)
        response_experiment = id |> get_experiment

        if (response_experiment |> isnothing)
            return error_response(
                NotFound, "Experiment not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_experiment; status=HTTP.StatusCodes.OK)
    end

    @get root("/project/{project_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Experiment, ReadPermission),
    ]) function (request::HTTP.Request, project_id::Integer)
        page = request |> parse_pagination
        return json(get_experiments(project_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root("/project/{project_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Experiment, CreatePermission),
    ]) function (
        ::HTTP.Request,
        project_id::Integer,
        parameters::Json{ExperimentCreatePayload},
    )
        experiment_id, upsert_result = create_experiment(
            project_id,
            parameters.payload.status_id,
            parameters.payload.name,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create experiment";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(
            ("experiment_id" => experiment_id); status=HTTP.StatusCodes.CREATED,
        )
    end

    @patch root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Experiment, UpdatePermission),
    ]) function (
        ::HTTP.Request, id::Integer, parameters::Json{ExperimentUpdatePayload}
    )
        upsert_result = update_experiment(
            id,
            parameters.payload.status_id,
            parameters.payload.name,
            parameters.payload.description,
            parameters.payload.end_date,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update experiment";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("message" => (upsert_result |> String)); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Experiment, DeletePermission),
    ]) function (::HTTP.Request, id::Integer)
        success = id |> delete_experiment

        if !success
            return error_response(
                ServerError, "Failed to delete experiment";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
