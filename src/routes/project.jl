"""
    setup_project_routes()

This function sets up the project-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_project_routes()
    root = router("/project", tags=["project"])

    @get root("/{id}") function (request::HTTP.Request, id::Integer)
        response_project = id |> get_project_by_id

        if (response_project |> isnothing)
            return json(
                ("message" => (HTTP.StatusCodes.NOT_FOUND |> HTTP.statustext));
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_project; status=HTTP.StatusCodes.OK)
    end

    @get root("/") function (request::HTTP.Request)
        return json(get_projects(); status=HTTP.StatusCodes.OK)
    end

    @post root("/") @admin_required function (
        request::HTTP.Request, parameters::Json{ProjectCreatePayload}
    )
        project_id, upsert_result = create_project(user.id, parameters.payload.name)
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("project_id" => project_id); status=upsert_status)
    end

    @patch root("/{id}") function (
        request::HTTP.Request, id::Integer, parameters::Json{ProjectUpdatePayload}
    )
        upsert_result = update_project(
            id,
            parameters.payload.name,
            parameters.payload.description,
        )
        upsert_status = upsert_result |> get_status_by_upsert_result
        return json(("message" => (upsert_result |> String)); status=upsert_status)
    end

    @delete root("/{id}") function (request::HTTP.Request, id::Integer)
        success = id |> delete_project

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
