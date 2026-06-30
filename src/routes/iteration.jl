"""
    setup_iteration_routes()

Register iteration routes (`/iteration`). Internal use only.
"""
function setup_iteration_routes()
    root = router("/iteration"; tags=["iteration"])

    @get root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Iteration, ReadPermission)]
    ) function (::HTTP.Request, id::String)
        response_iteration = get_iteration(id)

        if (isnothing(response_iteration))
            return error_response(
                NotFound, "Iteration not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(response_iteration; status=HTTP.StatusCodes.OK)
    end

    @get root(
        "/experiment/{experiment_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Iteration, ReadPermission)],
    ) function (request::HTTP.Request, experiment_id::String)
        page = parse_pagination(request)
        return json(get_iterations(experiment_id, page); status=HTTP.StatusCodes.OK)
    end

    @get root(
        "/{id}/children",
        middleware=[ProjectPermissionRequiredMiddleware(Iteration, ReadPermission)],
    ) function (::HTTP.Request, id::String)
        return json(get_child_iterations(id); status=HTTP.StatusCodes.OK)
    end

    # Snapshot endpoint: the client captures local git + Pkg state in its own process and
    # POSTs the bundle; the server persists it on the iteration row. Modelled as POST rather
    # than PATCH because it's a single "attach a snapshot to this run" action, not a partial
    # field update.
    @post root(
        "/{id}/snapshot",
        middleware=[ProjectPermissionRequiredMiddleware(Iteration, UpdatePermission)],
    ) function (::HTTP.Request, id::String, parameters::Json{IterationSnapshotPayload})
        iteration = get_iteration(id)
        if isnothing(iteration)
            return error_response(
                NotFound, "Iteration not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        upsert_result = update(
            Iteration,
            id;
            julia_version=parameters.payload.julia_version,
            git_sha=parameters.payload.git_sha,
            git_dirty=(Int(parameters.payload.git_dirty)),
            entrypoint=parameters.payload.entrypoint,
            project_toml=parameters.payload.project_toml,
            manifest_toml=parameters.payload.manifest_toml,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to attach snapshot";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @post root(
        "/experiment/{experiment_id}",
        middleware=[ProjectPermissionRequiredMiddleware(Iteration, CreatePermission)],
    ) function (request::HTTP.Request, experiment_id::String)
        # Optional `?parent_iteration_id=<id>` query param makes the new row a child of that
        # iteration. Absent → top-level iteration (the legacy default). A non-existent or
        # cross-experiment parent is rejected downstream by `create_iteration`.
        qp = queryparams(request)
        parent_iteration_id = get(qp, "parent_iteration_id", nothing)

        iteration_id, upsert_result = create_iteration(
            experiment_id; parent_iteration_id=parent_iteration_id
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create iteration";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("iteration_id" => iteration_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(Iteration, UpdatePermission)],
    ) function (::HTTP.Request, id::String, parameters::Json{IterationUpdatePayload})
        upsert_result = update_iteration(
            id,
            parameters.payload.notes,
            parameters.payload.end_date;
            status_id=parameters.payload.status_id,
            error_message=parameters.payload.error_message,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update iteration";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root(
        "/{id}",
        middleware=[ProjectPermissionRequiredMiddleware(Iteration, DeletePermission)],
    ) function (::HTTP.Request, id::String)
        success = delete_iteration(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete iteration";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
