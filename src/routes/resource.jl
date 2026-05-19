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

    # Streaming bytes endpoint. Returns the raw artifact contents with an
    # `application/octet-stream` Content-Type — backend-agnostic, so SQLite-backed rows
    # return their inline bytes and external rows are dereferenced through the artifact
    # store.
    @get root("/{id}/data", middleware=[
        ProjectPermissionRequiredMiddleware(Resource, ReadPermission),
    ]) function (::HTTP.Request, id::Integer)
        response_resource = id |> get_resource
        if (response_resource |> isnothing)
            return error_response(
                NotFound, "Resource not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end

        bytes = id |> read_resource_data
        if bytes |> isnothing
            return error_response(
                NotFound, "Resource not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return HTTP.Response(
            HTTP.StatusCodes.OK,
            [
                "Content-Type" => "application/octet-stream",
                "Content-Length" => bytes |> length |> string,
            ],
            bytes,
        )
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
        # Both `name` and `data` are required, but `find` returns `nothing` when a part is
        # absent — dereference `.data` only after we know the part exists.
        name_part = find(form_data, "name")
        data_part = find(form_data, "data")
        if (name_part |> isnothing) || (data_part |> isnothing)
            return error_response(
                InvalidPayload, "Multipart fields 'name' and 'data' are required";
                status=HTTP.StatusCodes.UNPROCESSABLE_ENTITY,
            )
        end

        resource_id, upsert_result = create_resource(
            experiment_id,
            name_part.data |> take! |> String,
            data_part.data |> take!,
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
        # Any subset of these parts may be sent; `find` returns `nothing` when one is absent.
        name_part = find(form_data, "name")
        description_part = find(form_data, "description")
        data_part = find(form_data, "data")

        upsert_result = update_resource(
            id,
            (name_part |> isnothing) ? nothing : (name_part.data |> take! |> String),
            (description_part |> isnothing) ? nothing : (description_part.data |> take! |> String),
            (data_part |> isnothing) ? nothing : (data_part.data |> take!),
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
