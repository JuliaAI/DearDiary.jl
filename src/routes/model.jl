"""
    setup_model_routes()

Register model-registry routes (`/model`). Internal use only.
"""
function setup_model_routes()
    root = router("/model"; tags=["model"])

    @get root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Model, ReadPermission)]
    ) function (::HTTP.Request, id::Integer)
        response_model = get_model(id)

        if (isnothing(response_model))
            return error_response(
                NotFound, "Model not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(response_model; status=HTTP.StatusCodes.OK)
    end

    @get root(
        "/project/{project_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Model, ReadPermission)],
    ) function (request::HTTP.Request, project_id::Integer)
        page = parse_pagination(request)
        return json(get_models(project_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root(
        "/project/{project_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Model, CreatePermission)],
    ) function (::HTTP.Request, project_id::Integer, parameters::Json{ModelCreatePayload})
        model_id, upsert_result = create_model(project_id, parameters.payload.name)
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create model";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        # The description is optional at the type level but the registry only stores a
        # non-null `description` once the row exists; apply it as a follow-up update.
        if !(isnothing(parameters.payload.description))
            update_model(model_id, nothing, parameters.payload.description)
        end
        return json(("model_id" => model_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Model, UpdatePermission)]
    ) function (::HTTP.Request, id::Integer, parameters::Json{ModelUpdatePayload})
        upsert_result = update_model(
            id, parameters.payload.name, parameters.payload.description
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update model";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Model, DeletePermission)]
    ) function (::HTTP.Request, id::Integer)
        success = delete_model(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete model";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
