"""
    setup_tag_routes()

This function sets up the tag-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_tag_routes()
    root = router("/tag", tags=["tag"])

    @get root("/{id}", middleware=[AdminRequiredMiddleware]) function (
        ::HTTP.Request, id::Integer,
    )
        response_tag = id |> get_tag

        if (response_tag |> isnothing)
            return error_response(
                NotFound, "Tag not found";
                status=HTTP.StatusCodes.NOT_FOUND,
            )
        end
        return json(response_tag; status=HTTP.StatusCodes.OK)
    end

    @get root("/project/{project_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Tag, ReadPermission),
    ]) function (::HTTP.Request, project_id::Integer)
        return json(get_tags(Project, project_id); status=HTTP.StatusCodes.OK)
    end

    @get root("/experiment/{experiment_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Tag, ReadPermission),
    ]) function (::HTTP.Request, experiment_id::Integer)
        return json(get_tags(Experiment, experiment_id); status=HTTP.StatusCodes.OK)
    end

    @get root("/iteration/{iteration_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Tag, ReadPermission),
    ]) function (::HTTP.Request, iteration_id::Integer)
        return json(get_tags(Iteration, iteration_id); status=HTTP.StatusCodes.OK)
    end

    @post root("/project/{project_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Tag, CreatePermission),
    ]) function (
        ::HTTP.Request, project_id::Integer, parameters::Json{TagCreatePayload},
    )
        association_id, upsert_result = add_tag(
            Project, project_id, parameters.payload.value,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to attach tag to project";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("association_id" => association_id); status=HTTP.StatusCodes.CREATED)
    end

    @post root("/experiment/{experiment_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Tag, CreatePermission),
    ]) function (
        ::HTTP.Request, experiment_id::Integer, parameters::Json{TagCreatePayload},
    )
        association_id, upsert_result = add_tag(
            Experiment, experiment_id, parameters.payload.value,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to attach tag to experiment";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("association_id" => association_id); status=HTTP.StatusCodes.CREATED)
    end

    @post root("/iteration/{iteration_id}", middleware=[
        ProjectPermissionRequiredMiddleware(Tag, CreatePermission),
    ]) function (
        ::HTTP.Request, iteration_id::Integer, parameters::Json{TagCreatePayload},
    )
        association_id, upsert_result = add_tag(
            Iteration, iteration_id, parameters.payload.value,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to attach tag to iteration";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("association_id" => association_id); status=HTTP.StatusCodes.CREATED)
    end

    @delete root("/{id}", middleware=[AdminRequiredMiddleware]) function (
        ::HTTP.Request, id::Integer,
    )
        success = id |> delete_tag

        if !success
            return error_response(
                ServerError, "Failed to delete tag";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
