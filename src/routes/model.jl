"""
    setup_model_routes()

This function sets up the model-registry routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_model_routes()
    root = router("/model", tags=["model"])

    @get root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Model, ReadPermission),
    ]) function (::HTTP.Request, id::Integer)
        response_model = id |> get_model

        if (response_model |> isnothing)
            return error_response(
                NotFound, "Model not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_model; status=HTTP.StatusCodes.OK)
    end

    @get root("/project/{project_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Model, ReadPermission),
    ]) function (request::HTTP.Request, project_id::Integer)
        page = request |> parse_pagination
        return json(get_models(project_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root("/project/{project_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Model, CreatePermission),
    ]) function (
        ::HTTP.Request,
        project_id::Integer,
        parameters::Json{ModelCreatePayload},
    )
        model_id, upsert_result = create_model(
            project_id,
            parameters.payload.name,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create model";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        # The description is optional at the type level but the registry only stores a
        # non-null `description` once the row exists — apply it as a follow-up update.
        if !(parameters.payload.description |> isnothing)
            update_model(model_id, nothing, parameters.payload.description)
        end
        return json(("model_id" => model_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Model, UpdatePermission),
    ]) function (
        ::HTTP.Request, id::Integer, parameters::Json{ModelUpdatePayload}
    )
        upsert_result = update_model(
            id,
            parameters.payload.name,
            parameters.payload.description,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update model";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("message" => (upsert_result |> String)); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Model, DeletePermission),
    ]) function (::HTTP.Request, id::Integer)
        success = id |> delete_model

        if !success
            return error_response(
                ServerError, "Failed to delete model";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
