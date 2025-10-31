"""
    setup_experiment_routes()

This function sets up the experiment-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_experiment_routes()
    root = router("/experiment", tags=["experiment"])

    @get root("/{id}") function (request::HTTP.Request, id::Integer)
        response_experiment = id |> get_experiment_by_id

        if (response_experiment |> isnothing)
            return json(
                ("message" => (HTTP.StatusCodes.NOT_FOUND |> HTTP.statustext));
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_experiment; status=HTTP.StatusCodes.OK)
    end

    @get root("/project/{project_id}") function (
        request::HTTP.Request, project_id::Integer
    )
        return json((project_id |> get_experiments); status=HTTP.StatusCodes.OK)
    end

    @post root("/project/{project_id}") function (
        request::HTTP.Request,
        project_id::Integer,
        parameters::Json{ExperimentCreatePayload},
    )
        experiment_id, upsert_result = create_experiment(
            project_id,
            parameters.payload.status_id,
            parameters.payload.name,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("experiment_id" => experiment_id); status=upsert_status)
    end

    @patch root("/{id}") function (
        request::HTTP.Request, id::Integer, parameters::Json{ExperimentUpdatePayload}
    )
        upsert_result = update_experiment(
            id,
            parameters.payload.status_id,
            parameters.payload.name,
            parameters.payload.description,
            parameters.payload.end_date,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("message" => (upsert_result |> String)); status=upsert_status)
    end

    @delete root("/{id}") function (request::HTTP.Request, id::Integer)
        success = id |> delete_experiment

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
