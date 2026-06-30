@testset verbose = true "routes utilities" begin
    @testset verbose = true "get status by upsert result" begin
        upsert_result_to_status = [
            (DearDiary.Created, HTTP.StatusCodes.CREATED),
            (DearDiary.Duplicate, HTTP.StatusCodes.CONFLICT),
            (DearDiary.Unprocessable, HTTP.StatusCodes.UNPROCESSABLE_ENTITY),
            (DearDiary.Error, HTTP.StatusCodes.INTERNAL_SERVER_ERROR),
        ]

        for (upsert_result, status) in upsert_result_to_status
            @test DearDiary.get_status_by_upsert_result(upsert_result) == status
        end
    end

    @testset verbose = true "error_code returns stable identifiers" begin
        code_strings = [
            (DearDiary.NotFound, "NOT_FOUND"),
            (DearDiary.InvalidCredentials, "INVALID_CREDENTIALS"),
            (DearDiary.TokenMissing, "TOKEN_MISSING"),
            (DearDiary.TokenInvalid, "TOKEN_INVALID"),
            (DearDiary.TokenExpired, "TOKEN_EXPIRED"),
            (DearDiary.TokenPayloadInvalid, "TOKEN_PAYLOAD_INVALID"),
            (DearDiary.UserNotFound, "USER_NOT_FOUND"),
            (DearDiary.AdminRequired, "ADMIN_REQUIRED"),
            (DearDiary.SameUserRequired, "SAME_USER_REQUIRED"),
            (DearDiary.ProjectPermissionRequired, "PROJECT_PERMISSION_REQUIRED"),
            (DearDiary.Conflict, "CONFLICT"),
            (DearDiary.InvalidPayload, "INVALID_PAYLOAD"),
            (DearDiary.ServerError, "SERVER_ERROR"),
        ]
        for (code, expected) in code_strings
            @test DearDiary.error_code(code) == expected
        end
    end

    @testset verbose = true "upsert_to_error_code dispatch" begin
        @test DearDiary.upsert_to_error_code(DearDiary.Duplicate) === DearDiary.Conflict
        @test DearDiary.upsert_to_error_code(DearDiary.Unprocessable) ===
            DearDiary.InvalidPayload
        @test DearDiary.upsert_to_error_code(DearDiary.Error) === DearDiary.ServerError
    end

    @with_deardiary_test_db begin
        @testset verbose = true "admin required macro" begin
            @testset verbose = true "as an admin" begin
                payload = JSON.json(Dict("username" => "default", "password" => "default"))
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth"; body=payload, status_exception=false
                )
                token = JSON.parse(String(response.body), Dict{String,Any})["access_token"]

                create_payload = JSON.json(
                    Dict(
                        "first_name" => "Missy",
                        "last_name" => "Gala",
                        "username" => "missy",
                        "password" => "gala",
                    ),
                )
                response = HTTP.post(
                    "http://127.0.0.1:9000/user";
                    headers=Dict("Authorization" => "Bearer $token"),
                    body=create_payload,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.CREATED
            end

            @testset verbose = true "as a non-admin" begin
                payload = JSON.json(Dict("username" => "missy", "password" => "gala"))
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth"; body=payload, status_exception=false
                )
                token = JSON.parse(String(response.body), Dict{String,Any})["access_token"]

                create_payload = JSON.json(
                    Dict(
                        "first_name" => "Choclo",
                        "last_name" => "Queso",
                        "username" => "choclo",
                        "password" => "queso",
                    ),
                )
                response = HTTP.post(
                    "http://127.0.0.1:9000/user";
                    headers=Dict("Authorization" => "Bearer $token"),
                    body=create_payload,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.FORBIDDEN
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "ADMIN_REQUIRED"
            end
        end

        @testset verbose = true "same-user-or-admin middleware" begin
            missy_token = JSON.parse(
                String(
                    HTTP.post(
                        "http://127.0.0.1:9000/auth";
                        body=(JSON.json(Dict("username" => "missy", "password" => "gala"))),
                        status_exception=false,
                    ).body,
                ),
                Dict{String,Any},
            )["access_token"]
            missy = DearDiary.get_user_by_username("missy")
            missy_headers = Dict("Authorization" => "Bearer $missy_token")

            @testset "user can read own profile" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/user/$(missy.id)";
                    headers=missy_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["username"] == "missy"
                @test !haskey(data, "password")
            end

            @testset "user cannot read another user's profile" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=missy_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.FORBIDDEN
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "SAME_USER_REQUIRED"
            end

            @testset "admin can read any profile" begin
                admin_token = JSON.parse(
                    String(
                        HTTP.post(
                            "http://127.0.0.1:9000/auth";
                            body=(JSON.json(
                                Dict("username" => "default", "password" => "default")
                            )),
                            status_exception=false,
                        ).body,
                    ),
                    Dict{String,Any},
                )["access_token"]

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/$(missy.id)";
                    headers=Dict("Authorization" => "Bearer $admin_token"),
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
            end
        end

        @testset verbose = true "user admin-field authorization" begin
            admin_token = JSON.parse(
                String(
                    HTTP.post(
                        "http://127.0.0.1:9000/auth";
                        body=(JSON.json(
                            Dict("username" => "default", "password" => "default")
                        )),
                        status_exception=false,
                    ).body,
                ),
                Dict{String,Any},
            )["access_token"]
            admin_headers = Dict("Authorization" => "Bearer $admin_token")

            HTTP.post(
                "http://127.0.0.1:9000/user";
                headers=admin_headers,
                body=(JSON.json(
                    Dict(
                        "first_name" => "Promo",
                        "last_name" => "Seeker",
                        "username" => "promo",
                        "password" => "secret",
                    ),
                )),
                status_exception=false,
            )
            promo = DearDiary.get_user_by_username("promo")
            promo_token = JSON.parse(
                String(
                    HTTP.post(
                        "http://127.0.0.1:9000/auth";
                        body=(JSON.json(
                            Dict("username" => "promo", "password" => "secret")
                        )),
                        status_exception=false,
                    ).body,
                ),
                Dict{String,Any},
            )["access_token"]
            promo_headers = Dict("Authorization" => "Bearer $promo_token")

            @testset "non-admin cannot self-promote to admin" begin
                response = HTTP.patch(
                    "http://127.0.0.1:9000/user/$(promo.id)";
                    headers=promo_headers,
                    body=(JSON.json(Dict("is_admin" => true))),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.FORBIDDEN
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "ADMIN_REQUIRED"
                @test DearDiary.get_user_by_username("promo").is_admin == false
            end

            @testset "non-admin can still edit own non-privileged fields" begin
                response = HTTP.patch(
                    "http://127.0.0.1:9000/user/$(promo.id)";
                    headers=promo_headers,
                    body=(JSON.json(Dict("first_name" => "Renamed"))),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.OK
                refreshed = DearDiary.get_user_by_username("promo")
                @test refreshed.first_name == "Renamed"
                @test refreshed.is_admin == false
            end

            @testset "admin can grant admin to a user" begin
                response = HTTP.patch(
                    "http://127.0.0.1:9000/user/$(promo.id)";
                    headers=admin_headers,
                    body=(JSON.json(Dict("is_admin" => true))),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.OK
                @test DearDiary.get_user_by_username("promo").is_admin == true
            end
        end

        @testset verbose = true "list permissions endpoints" begin
            admin_token = JSON.parse(
                String(
                    HTTP.post(
                        "http://127.0.0.1:9000/auth";
                        body=(JSON.json(
                            Dict("username" => "default", "password" => "default")
                        )),
                        status_exception=false,
                    ).body,
                ),
                Dict{String,Any},
            )["access_token"]
            admin_headers = Dict("Authorization" => "Bearer $admin_token")

            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                headers=admin_headers,
                body=(JSON.json(Dict("name" => "Listing Project"))),
                status_exception=false,
            )
            project_id = JSON.parse(String(project_response.body), Dict{String,Any})["project_id"]

            missy = DearDiary.get_user_by_username("missy")
            DearDiary.create_userpermission(missy.id, project_id, false, true, false, false)

            missy_token = JSON.parse(
                String(
                    HTTP.post(
                        "http://127.0.0.1:9000/auth";
                        body=(JSON.json(Dict("username" => "missy", "password" => "gala"))),
                        status_exception=false,
                    ).body,
                ),
                Dict{String,Any},
            )["access_token"]
            missy_headers = Dict("Authorization" => "Bearer $missy_token")

            @testset "GET /project/{id}/members lists project members" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/project/$(project_id)/members";
                    headers=admin_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(String(response.body), Array{Dict{String,Any},1})
                @test (length(data)) == 2
                user_ids = (d -> d["user_id"]).(data)
                @test missy.id in user_ids
            end

            @testset "GET /project/{id}/members readable by member" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/project/$(project_id)/members";
                    headers=missy_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
            end

            @testset "GET /project/{id}/members forbidden for non-member" begin
                outsider_id, _ = DearDiary.create_user("Out", "Sider", "outsider", "secret")
                outsider_token = JSON.parse(
                    String(
                        HTTP.post(
                            "http://127.0.0.1:9000/auth";
                            body=(JSON.json(
                                Dict("username" => "outsider", "password" => "secret")
                            )),
                            status_exception=false,
                        ).body,
                    ),
                    Dict{String,Any},
                )["access_token"]

                response = HTTP.get(
                    "http://127.0.0.1:9000/project/$(project_id)/members";
                    headers=Dict("Authorization" => "Bearer $outsider_token"),
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.FORBIDDEN
            end

            @testset "GET /user/{id}/permissions self-access" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/user/$(missy.id)/permissions";
                    headers=missy_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(String(response.body), Array{Dict{String,Any},1})
                project_ids = (d -> d["project_id"]).(data)
                @test project_id in project_ids
            end

            @testset "GET /user/{id}/permissions forbidden for other users" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1/permissions";
                    headers=missy_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.FORBIDDEN
            end

            @testset "GET /user/{id}/permissions admin can list any" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/user/$(missy.id)/permissions";
                    headers=admin_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
            end
        end

        @testset verbose = true "project permission middleware" begin
            admin_token = JSON.parse(
                String(
                    HTTP.post(
                        "http://127.0.0.1:9000/auth";
                        body=(JSON.json(
                            Dict("username" => "default", "password" => "default")
                        )),
                        status_exception=false,
                    ).body,
                ),
                Dict{String,Any},
            )["access_token"]
            admin_headers = Dict("Authorization" => "Bearer $admin_token")

            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                headers=admin_headers,
                body=(JSON.json(Dict("name" => "Permission Project"))),
                status_exception=false,
            )
            project_id = JSON.parse(String(project_response.body), Dict{String,Any})["project_id"]

            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                headers=admin_headers,
                body=(JSON.json(
                    Dict(
                        "status_id" => (Integer(DearDiary.IN_PROGRESS)),
                        "name" => "Permission Experiment",
                    ),
                )),
                status_exception=false,
            )
            experiment_id = JSON.parse(String(experiment_response.body), Dict{String,Any})["experiment_id"]

            user = DearDiary.get_user_by_username("missy")
            user_token = JSON.parse(
                String(
                    HTTP.post(
                        "http://127.0.0.1:9000/auth";
                        body=(JSON.json(Dict("username" => "missy", "password" => "gala"))),
                        status_exception=false,
                    ).body,
                ),
                Dict{String,Any},
            )["access_token"]
            user_headers = Dict("Authorization" => "Bearer $user_token")

            @testset "admin bypasses permission check" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/experiment/$(experiment_id)";
                    headers=admin_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
            end

            @testset "non-admin without permission record is forbidden" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/experiment/$(experiment_id)";
                    headers=user_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.FORBIDDEN
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "PROJECT_PERMISSION_REQUIRED"
            end

            @testset "non-admin with read permission can read but not create" begin
                _, _ = DearDiary.create_userpermission(
                    user.id, project_id, false, true, false, false
                )

                read_response = HTTP.get(
                    "http://127.0.0.1:9000/experiment/$(experiment_id)";
                    headers=user_headers,
                    status_exception=false,
                )
                @test read_response.status == HTTP.StatusCodes.OK

                create_response = HTTP.post(
                    "http://127.0.0.1:9000/experiment/project/$(project_id)";
                    headers=user_headers,
                    body=(JSON.json(
                        Dict(
                            "status_id" => (Integer(DearDiary.IN_PROGRESS)),
                            "name" => "Forbidden Experiment",
                        ),
                    )),
                    status_exception=false,
                )
                @test create_response.status == HTTP.StatusCodes.FORBIDDEN
            end

            @testset "granting create permission allows POST" begin
                permission = DearDiary.get_userpermission(user.id, project_id)
                @test DearDiary.update_userpermission(
                    permission.id, true, nothing, nothing, nothing
                ) === DearDiary.Updated

                response = HTTP.post(
                    "http://127.0.0.1:9000/experiment/project/$(project_id)";
                    headers=user_headers,
                    body=(JSON.json(
                        Dict(
                            "status_id" => (Integer(DearDiary.IN_PROGRESS)),
                            "name" => "Allowed Experiment",
                        ),
                    )),
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.CREATED
            end

            @testset "update and delete dispatch on the matching action" begin
                permission = DearDiary.get_userpermission(user.id, project_id)

                update_payload = JSON.json(
                    Dict(
                        "status_id" => (Integer(DearDiary.STOPPED)),
                        "name" => nothing,
                        "description" => "edited",
                        "end_date" => nothing,
                    ),
                )

                forbidden_update = HTTP.patch(
                    "http://127.0.0.1:9000/experiment/$(experiment_id)";
                    headers=user_headers,
                    body=update_payload,
                    status_exception=false,
                )
                @test forbidden_update.status == HTTP.StatusCodes.FORBIDDEN

                DearDiary.update_userpermission(
                    permission.id, nothing, nothing, true, nothing
                )
                allowed_update = HTTP.patch(
                    "http://127.0.0.1:9000/experiment/$(experiment_id)";
                    headers=user_headers,
                    body=update_payload,
                    status_exception=false,
                )
                @test allowed_update.status == HTTP.StatusCodes.OK

                forbidden_delete = HTTP.delete(
                    "http://127.0.0.1:9000/experiment/$(experiment_id)";
                    headers=user_headers,
                    status_exception=false,
                )
                @test forbidden_delete.status == HTTP.StatusCodes.FORBIDDEN

                DearDiary.update_userpermission(
                    permission.id, nothing, nothing, nothing, true
                )
                allowed_delete = HTTP.delete(
                    "http://127.0.0.1:9000/experiment/$(experiment_id)";
                    headers=user_headers,
                    status_exception=false,
                )
                @test allowed_delete.status == HTTP.StatusCodes.OK
            end

            @testset "missing entity short-circuits to NOT FOUND" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/experiment/9999";
                    headers=user_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.NOT_FOUND
            end
        end

        @testset verbose = true "get_project_id resolvers" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Resolver Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Resolver Experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            metric_id, _ = DearDiary.create_metric(iteration_id, "loss", 0.42)
            parameter_id, _ = DearDiary.create_parameter(iteration_id, "lr", "0.001")
            resource_id, _ = DearDiary.create_resource(
                experiment_id, "model.bin", UInt8[0x01, 0x02, 0x03]
            )

            req(target::AbstractString)::HTTP.Request = HTTP.Request("GET", target)

            @testset verbose = true "Iteration" begin
                @test DearDiary.get_project_id(
                    DearDiary.Iteration, req("/iteration/experiment/$(experiment_id)")
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Iteration, req("/iteration/$(iteration_id)")
                ) == project_id
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.Iteration, req("/iteration/9999"))
                )
                @test isnothing(
                    DearDiary.get_project_id(
                        DearDiary.Iteration, req("/iteration/experiment/9999")
                    ),
                )
                @test isnothing(
                    DearDiary.get_project_id(
                        DearDiary.Iteration, req("/iteration/not-a-number")
                    ),
                )
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.Iteration, req("/iteration"))
                )
            end

            @testset verbose = true "Metric" begin
                @test DearDiary.get_project_id(
                    DearDiary.Metric, req("/metric/iteration/$(iteration_id)")
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Metric, req("/metric/$(metric_id)")
                ) == project_id
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.Metric, req("/metric/9999"))
                )
                @test isnothing(
                    DearDiary.get_project_id(
                        DearDiary.Metric, req("/metric/iteration/9999")
                    ),
                )
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.Metric, req("/metric/not-a-number"))
                )
            end

            @testset verbose = true "Parameter" begin
                @test DearDiary.get_project_id(
                    DearDiary.Parameter, req("/parameter/iteration/$(iteration_id)")
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Parameter, req("/parameter/$(parameter_id)")
                ) == project_id
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.Parameter, req("/parameter/9999"))
                )
                @test isnothing(
                    DearDiary.get_project_id(
                        DearDiary.Parameter, req("/parameter/iteration/9999")
                    ),
                )
                @test isnothing(
                    DearDiary.get_project_id(
                        DearDiary.Parameter, req("/parameter/not-a-number")
                    ),
                )
            end

            @testset verbose = true "Resource" begin
                @test DearDiary.get_project_id(
                    DearDiary.Resource, req("/resource/experiment/$(experiment_id)")
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Resource, req("/resource/$(resource_id)")
                ) == project_id
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.Resource, req("/resource/9999"))
                )
                @test isnothing(
                    DearDiary.get_project_id(
                        DearDiary.Resource, req("/resource/experiment/9999")
                    ),
                )
                @test isnothing(
                    DearDiary.get_project_id(
                        DearDiary.Resource, req("/resource/not-a-number")
                    ),
                )
            end

            @testset verbose = true "UserPermission" begin
                @test DearDiary.get_project_id(
                    DearDiary.UserPermission, req("/project/$(project_id)/members")
                ) == project_id
                # A project-id path segment is the project id itself, taken verbatim (ids are
                # opaque UUID strings now). The permission middleware denies an unknown project.
                @test DearDiary.get_project_id(
                    DearDiary.UserPermission, req("/project/not-a-number/members")
                ) == "not-a-number"
                @test isnothing(
                    DearDiary.get_project_id(
                        DearDiary.UserPermission, req("/userpermission/$(project_id)")
                    ),
                )
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.UserPermission, req("/project"))
                )
            end

            @testset verbose = true "Tag" begin
                @test DearDiary.get_project_id(
                    DearDiary.Tag, req("/tag/project/$(project_id)")
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Tag, req("/tag/experiment/$(experiment_id)")
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Tag, req("/tag/iteration/$(iteration_id)")
                ) == project_id
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.Tag, req("/tag/experiment/9999"))
                )
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.Tag, req("/tag/iteration/9999"))
                )
                # `/tag/project/{id}` scopes by the project id verbatim (opaque UUID strings);
                # the permission middleware denies an unknown project.
                @test DearDiary.get_project_id(
                    DearDiary.Tag, req("/tag/project/not-a-number")
                ) == "not-a-number"
                @test isnothing(
                    DearDiary.get_project_id(
                        DearDiary.Tag, req("/tag/unknown/$(project_id)")
                    ),
                )
                @test isnothing(
                    DearDiary.get_project_id(DearDiary.Tag, req("/tag/$(project_id)"))
                )
            end
        end
    end
end
