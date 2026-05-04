"""
    setup_project_routes()

This function sets up the project-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_project_routes()
    root = router("/project", tags=["project"])

    @get root("/{id}", middleware=[
        ProjectPermissionRequiredMiddleware(Project, ReadPermission),
    ]) function (::HTTP.Request, id::Integer)
        response_project = id |> get_project

        if (response_project |> isnothing)
            return error_response(
                NotFound, "Project not found";
                status=HTTP.StatusCodes.NOT_FOUND,
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
            get(request.context, :user, get_user("default"))
        end
        return json(get_projects(viewer); status=HTTP.StatusCodes.OK)
    end

    @get root("/{project_id}/members", middleware=[
        ProjectPermissionRequiredMiddleware(UserPermission, ReadPermission),
    ]) function (::HTTP.Request, project_id::Integer)
        return json(
            get_userpermissions(Project, project_id); status=HTTP.StatusCodes.OK,
        )
    end

    @post root("/", middleware=[AdminRequiredMiddleware]) function (
        request::HTTP.Request, parameters::Json{ProjectCreatePayload}
    )
        project_id, upsert_result = create_project(
            request.context[:user].id,
            parameters.payload.name,
        )
        if !(upsert_result === Created)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to create project";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("project_id" => project_id); status=HTTP.StatusCodes.CREATED)
    end

    @patch root("/{id}", middleware=[AdminRequiredMiddleware]) function (
        ::HTTP.Request, id::Integer, parameters::Json{ProjectUpdatePayload}
    )
        upsert_result = update_project(
            id,
            parameters.payload.name,
            parameters.payload.description,
        )
        if !(upsert_result === Updated)
            return error_response(
                upsert_to_error_code(upsert_result),
                "Failed to update project";
                status=upsert_result |> get_status_by_upsert_result,
            )
        end
        return json(("message" => (upsert_result |> String)); status=HTTP.StatusCodes.OK)
    end

    @delete root("/{id}", middleware=[AdminRequiredMiddleware]) function (
        ::HTTP.Request, id::Integer
    )
        success = id |> delete_project

        if !success
            return error_response(
                ServerError, "Failed to delete project";
                status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR,
            )
        end
        return json(
            ("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
            status=HTTP.StatusCodes.OK,
        )
    end
end
