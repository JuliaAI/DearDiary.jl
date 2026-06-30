"""
    setup_experiment_routes()

Register experiment routes (`/experiment`). Internal use only.
"""
function setup_experiment_routes()
    root = router("/experiment"; tags=["experiment"])

    @get root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(Experiment, ReadPermission)],
    ) function (::HTTP.Request, id::String)
        response_experiment = get_experiment(id)

        if (isnothing(response_experiment))
            return error_response(
                NotFound, "Experiment not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(response_experiment; status=HTTP.StatusCodes.OK)
    end

    @get root(
        "/project/{project_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Experiment, ReadPermission)],
    ) function (request::HTTP.Request, project_id::String)
        page = parse_pagination(request)
        return json(get_experiments(project_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root(
        "/project/{project_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Experiment, CreatePermission)],
    ) function (
        ::HTTP.Request, project_id::String, parameters::Json{ExperimentCreatePayload}
    )
        experiment_id, upsert_result = create_experiment(
            project_id, parameters.payload.status_id, parameters.payload.name
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create experiment";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("experiment_id" => experiment_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(Experiment, UpdatePermission)],
    ) function (::HTTP.Request, id::String, parameters::Json{ExperimentUpdatePayload})
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
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(Experiment, DeletePermission)],
    ) function (::HTTP.Request, id::String)
        success = delete_experiment(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete experiment";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
