"""
    setup_resource_routes()

This function sets up the resource-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_resource_routes()
    root = router("/resource", tags=["resource"])

    @get root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Resource, ReadPermission),
    ]) function (::HTTP.Request, id::Integer)
        response_resource = id |> get_resource

        if (response_resource |> isnothing)
            return error_response(
                NotFound, "Resource not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_resource; status=HTTP.StatusCodes.OK)
    end

    @get root("/experiment/{experiment_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Resource, ReadPermission),
    ]) function (request::HTTP.Request, experiment_id::Integer)
        page = request |> parse_pagination
        return json(get_resources(experiment_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root("/experiment/{experiment_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Resource, CreatePermission),
    ]) function (request::HTTP.Request, experiment_id::Integer)
        form_data = request |> HTTP.parse_multipart_form
        name = find(form_data, "name").data
        data = find(form_data, "data").data
        if name |> isnothing || data |> isnothing
            return error_response(
                InvalidPayload, "Multipart fields 'name' and 'data' are required";
                status=HTTP.StatusCodes.UNPROCESSABLE_ENTITY,
            )
        end

        resource_id, upsert_result = create_resource(
            experiment_id,
            name |> take! |> String,
            data |> take!,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create resource";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("resource_id" => resource_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Resource, UpdatePermission),
    ]) function (request::HTTP.Request, id::Integer)
        form_data = request |> HTTP.parse_multipart_form
        name = find(form_data, "name").data
        description = find(form_data, "description").data
        data = find(form_data, "data").data

        upsert_result = update_resource(
            id,
            name |> isnothing ? nothing : (name |> take! |> String),
            description |> isnothing ? nothing : (description |> take! |> String),
            data |> isnothing ? nothing : (data |> take!),
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update resource";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("message" => (upsert_result |> String)); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Resource, DeletePermission),
    ]) function (::HTTP.Request, id::Integer)
        success = id |> delete_resource

        if !success
            return error_response(
                ServerError, "Failed to delete resource";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
