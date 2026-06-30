"""
    setup_metric_routes()

Register metric routes (`/metric`). Internal use only.
"""
function setup_metric_routes()
    root = router("/metric"; tags=["metric"])

    @get root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Metric, ReadPermission)]
    ) function (::HTTP.Request, id::String)
        response_metric = get_metric(id)

        if (isnothing(response_metric))
            return error_response(
                NotFound, "Metric not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(response_metric; status=HTTP.StatusCodes.OK)
    end

    @get root(
        "/iteration/{iteration_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Metric, ReadPermission)],
    ) function (request::HTTP.Request, iteration_id::String)
        page = parse_pagination(request)
        return json(get_metrics(iteration_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root(
        "/iteration/{iteration_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Metric, CreatePermission)],
    ) function (::HTTP.Request, iteration_id::String, parameters::Json{MetricCreatePayload})
        metric_id, upsert_result = create_metric(
            iteration_id,
            parameters.payload.key,
            parameters.payload.value;
            step=parameters.payload.step,
            recorded_at=parameters.payload.recorded_at,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create metric";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("metric_id" => metric_id); status=HTTP.StatusCodes.CREATED)
    end

    @post root(
        "/iteration/{iteration_id}/batch",
        middleware=[ProjectPermissionRequiredMiddleware(Metric, CreatePermission)],
    ) function (::HTTP.Request, iteration_id::String, parameters::Json{MetricBatchPayload})
        # `MetricBatchPayload` carries an ordered array so the inserted ids align with the
        # client-side iteration order, which retries can use to determine what landed.
        items = Dict{String,Float64}(
            item.key => item.value for item in parameters.payload.metrics
        )
        result = log_metrics(
            iteration_id,
            items;
            step=parameters.payload.step,
            recorded_at=parameters.payload.recorded_at,
        )
        if !(result.status === Created)
            return error_response(
                upsert_to_error_code(result.status),
                "Failed to log metrics";
                status=(get_status_by_upsert_result(result.status)),
            )
        end
        return json(("metric_ids" => result.ids); status=HTTP.StatusCodes.CREATED)
    end

    @patch root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Metric, UpdatePermission)]
    ) function (::HTTP.Request, id::String, parameters::Json{MetricUpdatePayload})
        upsert_result = update_metric(
            id,
            parameters.payload.key,
            parameters.payload.value;
            step=parameters.payload.step,
            recorded_at=parameters.payload.recorded_at,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update metric";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Metric, DeletePermission)]
    ) function (::HTTP.Request, id::String)
        success = delete_metric(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete metric";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
