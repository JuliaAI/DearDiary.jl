"""
    setup_project_routes()

Register project routes (`/project`). Internal use only.
"""
function setup_project_routes()
    root = router("/project"; tags=["project"])

    @get root(
        "/{id}", middleware=[ProjectPermissionRequiredMiddleware(Project, ReadPermission)]
    ) function (::HTTP.Request, id::String)
        response_project = get_project(id)

        if (isnothing(response_project))
            return error_response(
                NotFound, "Project not found"; status=HTTP.StatusCodes.NOT_FOUND
            )
        end
        return json(response_project; status=HTTP.StatusCodes.OK)
    end

    @get root("/") function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG
        # Viewer scoping: admins see every project; non-admins only those with
        # `read_permission`. When auth is disabled the default admin user is
        # assumed, matching the convention used by the permission middlewares.
        viewer = if _DEARDIARY_APICONFIG.enable_auth
            request.context[:user]
        else
            get(request.context, :user, get_user_by_username("default"))
        end
        return json(get_projects(viewer); status=HTTP.StatusCodes.OK)
    end

    @get root(
        "/{project_id}/members",
        middleware=[ProjectPermissionRequiredMiddleware(UserPermission, ReadPermission)],
    ) function (::HTTP.Request, project_id::String)
        return json(get_userpermissions(Project, project_id); status=HTTP.StatusCodes.OK)
    end

    @post root("/", middleware=[AdminRequiredMiddleware]) function (
        request::HTTP.Request, parameters::Json{ProjectCreatePayload}
    )
        project_id, upsert_result = create_project(
            request.context[:user].id, parameters.payload.name
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create project";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("project_id" => project_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root("/{id}", middleware=[AdminRequiredMiddleware]) function (
        ::HTTP.Request, id::String, parameters::Json{ProjectUpdatePayload}
    )
        upsert_result = update_project(
            id, parameters.payload.name, parameters.payload.description
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update project";
                status=get_status_by_upsert_result(upsert_result),
            )
        end
        return json(("message" => (String(upsert_result))); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[AdminRequiredMiddleware]) function (
        ::HTTP.Request, id::String
    )
        success = delete_project(id)

        if !success
            return error_response(
                ServerError,
                "Failed to delete project";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.statustext(HTTP.StatusCodes.OK)));
            status=HTTP.StatusCodes.OK,
        )
    end
end
