"""
    setup_metric_routes()

This function sets up the metric-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_metric_routes()
    root = router("/metric", tags=["metric"])

    @get root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Metric, ReadPermission),
    ]) function (::HTTP.Request, id::Integer)
        response_metric = id |> get_metric

        if (response_metric |> isnothing)
            return error_response(
                NotFound, "Metric not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_metric; status=HTTP.StatusCodes.OK)
    end

    @get root("/iteration/{iteration_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Metric, ReadPermission),
    ]) function (request::HTTP.Request, iteration_id::Integer)
        page = request |> parse_pagination
        return json(get_metrics(iteration_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root("/iteration/{iteration_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Metric, CreatePermission),
    ]) function (
        ::HTTP.Request, iteration_id::Integer, parameters::Json{MetricCreatePayload}
    )
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
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("metric_id" => metric_id); status=HTTP.StatusCodes.CREATED)
    end

    @post root("/iteration/{iteration_id}/batch", middleware=[
        ProjectPermissionRequiredMiddleware(Metric, CreatePermission),
    ]) function (
        ::HTTP.Request, iteration_id::Integer, parameters::Json{MetricBatchPayload}
    )
        # `MetricBatchPayload` carries an ordered array so the inserted ids align with the
        # client-side iteration order — handy for retries that want to know what landed.
        items = Dict{String,Float64}(
            item.key => item.value for item in parameters.payload.metrics
        )
        result = log_metrics(
            iteration_id, items;
            step=parameters.payload.step,
            recorded_at=parameters.payload.recorded_at,
        )
        if !(result.status === Created)
            return error_response(
                upsert_to_error_code(result.status),
                "Failed to log metrics";
                status=result.status |> get_status_by_upsert_result,
            )
        end
        return json(
            ("metric_ids" => result.ids); status=HTTP.StatusCodes.CREATED,
        )
    end

    @patch root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Metric, UpdatePermission),
    ]) function (
        ::HTTP.Request, id::Integer, parameters::Json{MetricUpdatePayload}
    )
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
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("message" => (upsert_result |> String)); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Metric, DeletePermission),
    ]) function (::HTTP.Request, id::Integer)
        success = id |> delete_metric

        if !success
            return error_response(
                ServerError, "Failed to delete metric";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
