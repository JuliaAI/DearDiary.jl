"""
    setup_modelversion_routes()

Register model-version routes (`/modelversion`). Internal use only.
"""
function setup_modelversion_routes()
    root = router("/modelversion"; tags=["modelversion"])

    @get root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(ModelVersion, ReadPermission)],
    ) function (::HTTP.Request, id::Integer)
        response_version = get_modelversion(id)

        if (isnothing(response_version))
            return error_response(
                NotFound, "Model version not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(response_version; status=HTTP.StatusCodes.OK)
    end

    @get root(
        "/model/{model_id}",
        middleware=[ProjectPermissionRequiredMiddleware(ModelVersion, ReadPermission)],
    ) function (request::HTTP.Request, model_id::Integer)
        page = parse_pagination(request)
        return json(get_modelversions(model_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root(
        "/model/{model_id}",
        middleware=[ProjectPermissionRequiredMiddleware(ModelVersion, CreatePermission)],
    ) function (
        ::HTTP.Request, model_id::Integer, parameters::Json{ModelVersionCreatePayload}
    )
        version_id, upsert_result = create_modelversion(
            model_id,
            parameters.payload.iteration_id,
            parameters.payload.resource_id,
            if (isnothing(parameters.payload.description))
                ""
            else
                parameters.payload.description
            end,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create model version";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("modelversion_id" => version_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(ModelVersion, UpdatePermission)],
    ) function (::HTTP.Request, id::Integer, parameters::Json{ModelVersionUpdatePayload})
        upsert_result = update_modelversion(
            id,
            parameters.payload.stage_id,
            parameters.payload.description,
            parameters.payload.resource_id,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update model version";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(ModelVersion, DeletePermission)],
    ) function (::HTTP.Request, id::Integer)
        success = delete_modelversion(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete model version";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
