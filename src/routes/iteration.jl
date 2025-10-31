"""
    setup_iteration_routes()

This function sets up the iteration-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_iteration_routes()
    root = router("/iteration", tags=["iteration"])

    @get root("/{id}") function (request::HTTP.Request, id::Integer)
        response_iteration = id |> get_iteration_by_id

        if (response_iteration |> isnothing)
            return json(
                ("message" => (HTTP.StatusCodes.NOT_FOUND |> HTTP.statustext));
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_iteration; status=HTTP.StatusCodes.OK)
    end

    @get root("/experiment/{experiment_id}") function (
        request::HTTP.Request, experiment_id::Integer
    )
        return json((experiment_id |> get_iterations); status=HTTP.StatusCodes.OK)
    end

    @post root("/experiment/{experiment_id}") function (
        request::HTTP.Request, experiment_id::Integer
    )
        iteration_id, upsert_result = experiment_id |> create_iteration
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("iteration_id" => iteration_id); status=upsert_status)
    end

    @patch root("/{id}") function (
        request::HTTP.Request, id::Integer, parameters::Json{IterationUpdatePayload}
    )
        upsert_result = update_iteration(
            id,
            parameters.payload.notes,
            parameters.payload.end_date,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("message" => (upsert_result |> String)); status=upsert_status)
    end

    @delete root("/{id}") function (request::HTTP.Request, id::Integer)
        success = id |> delete_iteration

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
