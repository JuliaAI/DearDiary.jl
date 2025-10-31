"""
    setup_resource_routes()

This function sets up the resource-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_resource_routes()
    root = router("/resource", tags=["resource"])

    @get root("/{id}") function (request::HTTP.Request, id::Integer)
        response_resource = id |> get_resource_by_id

        if (response_resource |> isnothing)
            return json(
                ("message" => (HTTP.StatusCodes.NOT_FOUND |> HTTP.statustext));
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_resource; status=HTTP.StatusCodes.OK)
    end

    @get root("/experiment/{experiment_id}") function (
        request::HTTP.Request, experiment_id::Integer
    )
        return json((experiment_id |> get_resources); status=HTTP.StatusCodes.OK)
    end

    @post root("/experiment/{experiment_id}") function (
        request::HTTP.Request,
        experiment_id::Integer,
    )
        form_data = request |> HTTP.parse_multipart_form
        name = find(form_data, "name").data
        data = find(form_data, "data").data
        if name |> isnothing || data |> isnothing
            upsert_status = Unprocessable() |> get_status_by_upsert_result
            return json(("resource_id" => nothing); status=upsert_status)
        end

        resource_id, upsert_result = create_resource(
            experiment_id,
            name |> take! |> String,
            data |> take!,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("resource_id" => resource_id); status=upsert_status)
    end

    @patch root("/{id}") function (request::HTTP.Request, id::Integer)
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
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("message" => (upsert_result |> String)); status=upsert_status)
    end

    @delete root("/{id}") function (request::HTTP.Request, id::Integer)
        success = id |> delete_resource

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
