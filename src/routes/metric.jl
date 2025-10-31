"""
    setup_metric_routes()

This function sets up the metric-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_metric_routes()
    root = router("/metric", tags=["metric"])

    @get root("/{id}") function (request::HTTP.Request, id::Integer)
        response_metric = id |> get_metric_by_id

        if (response_metric |> isnothing)
            return json(
                ("message" => (HTTP.StatusCodes.NOT_FOUND |> HTTP.statustext));
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_metric; status=HTTP.StatusCodes.OK)
    end

    @get root("/iteration/{iteration_id}") function (
        request::HTTP.Request, iteration_id::Integer
    )
        return json((iteration_id |> get_metrics); status=HTTP.StatusCodes.OK)
    end

    @post root("/iteration/{iteration_id}") function (
        request::HTTP.Request, iteration_id::Integer, parameters::Json{MetricCreatePayload}
    )
        metric_id, upsert_result = create_metric(
            iteration_id,
            parameters.payload.key,
            parameters.payload.value,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("metric_id" => metric_id); status=upsert_status)
    end

    @patch root("/{id}") function (
        request::HTTP.Request, id::Integer, parameters::Json{MetricUpdatePayload}
    )
        upsert_result = update_metric(
            id,
            parameters.payload.key,
            parameters.payload.value,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("message" => (upsert_result |> String)); status=upsert_status)
    end

    @delete root("/{id}") function (request::HTTP.Request, id::Integer)
        success = id |> delete_metric

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
