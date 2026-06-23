"""
    setup_resource_routes()

Register resource routes (`/resource`). Internal use only.
"""
function setup_resource_routes()
    root = router("/resource"; tags=["resource"])

    @get root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Resource, ReadPermission)]
    ) function (::HTTP.Request, id::Integer)
        response_resource = get_resource(id)

        if (isnothing(response_resource))
            return error_response(
                NotFound, "Resource not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(response_resource; status=HTTP.StatusCodes.OK)
    end

    # Streaming bytes endpoint. Returns the raw artifact contents with an
    # `application/octet-stream` Content-Type. Backend-agnostic: inline-backed rows
    # return their inline bytes and external rows are dereferenced through the artifact
    # store.
    @get root(
        "/{id}/data",
        middleware=[ProjectPermissionRequiredMiddleware(Resource, ReadPermission)],
    ) function (::HTTP.Request, id::Integer)
        response_resource = get_resource(id)
        if (isnothing(response_resource))
            return error_response(
                NotFound, "Resource not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end

        bytes = read_resource_data(id)
        if isnothing(bytes)
            return error_response(
                NotFound, "Resource not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return HTTP.Response(
            HTTP.StatusCodes.OK,
            [
                "Content-Type" => "application/octet-stream",
                "Content-Length" => string(length(bytes)),
            ],
            bytes,
        )
    end

    @get root(
        "/experiment/{experiment_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Resource, ReadPermission)],
    ) function (request::HTTP.Request, experiment_id::Integer)
        page = parse_pagination(request)
        return json(get_resources(experiment_id, page); status=HTTP.StatusCodes.OK)
    end

    @post root(
        "/experiment/{experiment_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Resource, CreatePermission)],
    ) function (request::HTTP.Request, experiment_id::Integer)
        form_data = HTTP.parse_multipart_form(request)
        # Both `name` and `data` are required, but `find` returns `nothing` when a part is
        # absent; dereference `.data` only after we know the part exists.
        name_part = find(form_data, "name")
        data_part = find(form_data, "data")
        if (isnothing(name_part)) || (isnothing(data_part))
            return error_response(
                InvalidPayload,
                "Multipart fields 'name' and 'data' are required";
                status=HTTP.StatusCodes.UNPROCESSABLE_ENTITY,
            )
        end

        resource_id, upsert_result = create_resource(
            experiment_id, String(take!(name_part.data)), take!(data_part.data)
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create resource";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("resource_id" => resource_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(Resource, UpdatePermission)],
    ) function (request::HTTP.Request, id::Integer)
        form_data = HTTP.parse_multipart_form(request)
        # Any subset of these parts may be sent; `find` returns `nothing` when one is absent.
        name_part = find(form_data, "name")
        description_part = find(form_data, "description")
        data_part = find(form_data, "data")

        upsert_result = update_resource(
            id,
            (isnothing(name_part)) ? nothing : (String(take!(name_part.data))),
            if (isnothing(description_part))
                nothing
            else
                (String(take!(description_part.data)))
            end,
            (isnothing(data_part)) ? nothing : (take!(data_part.data)),
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update resource";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(Resource, DeletePermission)],
    ) function (::HTTP.Request, id::Integer)
        success = delete_resource(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete resource";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
