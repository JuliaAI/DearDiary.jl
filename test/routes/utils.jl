@testset verbose = true "routes utilities" begin
    @testset verbose = true "get status by upsert result" begin
        upsert_result_to_status = [
            (DearDiary.Created(), HTTP.StatusCodes.CREATED),
            (DearDiary.Duplicate(), HTTP.StatusCodes.CONFLICT),
            (DearDiary.Unprocessable(), HTTP.StatusCodes.UNPROCESSABLE_ENTITY),
            (DearDiary.Error(), HTTP.StatusCodes.INTERNAL_SERVER_ERROR),
        ]

        for (upsert_result, status) in upsert_result_to_status
            @test DearDiary.get_status_by_upsert_result(upsert_result) == status
        end
    end

    @with_deardiary_test_db begin
        @testset verbose = true "admin required macro" begin
            @testset verbose = true "as an admin" begin
                payload = Dict(
                    "username" => "default",
                    "password" => "default",
                ) |> JSON.json
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=payload,
                    status_exception=false,
                )
                token = JSON.parse(response.body |> String, Dict{String,Any})["access_token"]

                create_payload = Dict(
                    "first_name" => "Missy",
                    "last_name" => "Gala",
                    "username" => "missy",
                    "password" => "gala",
                ) |> JSON.json
                response = HTTP.post(
                    "http://127.0.0.1:9000/user";
                    headers=Dict("Authorization" => "Bearer $token"),
                    body=create_payload,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.CREATED
            end

            @testset verbose = true "as a non-admin" begin
                payload = Dict(
                    "username" => "missy",
                    "password" => "gala",
                ) |> JSON.json
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=payload,
                    status_exception=false,
                )
                token = JSON.parse(response.body |> String, Dict{String,Any})["access_token"]

                create_payload = Dict(
                    "first_name" => "Choclo",
                    "last_name" => "Queso",
                    "username" => "choclo",
                    "password" => "queso",
                ) |> JSON.json
                response = HTTP.post(
                    "http://127.0.0.1:9000/user";
                    headers=Dict("Authorization" => "Bearer $token"),
                    body=create_payload,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.FORBIDDEN
            end
        end

        @testset verbose = true "same-user-or-admin middleware" begin
            missy_token = JSON.parse(
                HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=(
                        Dict("username" => "missy", "password" => "gala") |> JSON.json
                    ),
                    status_exception=false,
                ).body |> String,
                Dict{String,Any},
            )["access_token"]
            missy = DearDiary.get_user("missy")
            missy_headers = Dict("Authorization" => "Bearer $missy_token")

            @testset "user can read own profile" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/user/$(missy.id)";
                    headers=missy_headers,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(response.body |> String, Dict{String,Any})
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
            end

            @testset "admin can read any profile" begin
                admin_token = JSON.parse(
                    HTTP.post(
                        "http://127.0.0.1:9000/auth";
                        body=(
                            Dict("username" => "default", "password" => "default") |> JSON.json
                        ),
                        status_exception=false,
                    ).body |> String,
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

        @testset verbose = true "project permission middleware" begin
            admin_token = JSON.parse(
                HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=(
                        Dict("username" => "default", "password" => "default") |> JSON.json
                    ),
                    status_exception=false,
                ).body |> String,
                Dict{String,Any},
            )["access_token"]
            admin_headers = Dict("Authorization" => "Bearer $admin_token")

            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                headers=admin_headers,
                body=(Dict("name" => "Permission Project") |> JSON.json),
                status_exception=false,
            )
            project_id = JSON.parse(
                project_response.body |> String, Dict{String,Any},
            )["project_id"]

            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                headers=admin_headers,
                body=(
                    Dict(
                        "status_id" => (DearDiary.IN_PROGRESS |> Integer),
                        "name" => "Permission Experiment",
                    ) |> JSON.json
                ),
                status_exception=false,
            )
            experiment_id = JSON.parse(
                experiment_response.body |> String, Dict{String,Any},
            )["experiment_id"]

            user = DearDiary.get_user("missy")
            user_token = JSON.parse(
                HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=(
                        Dict("username" => "missy", "password" => "gala") |> JSON.json
                    ),
                    status_exception=false,
                ).body |> String,
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
            end

            @testset "non-admin with read permission can read but not create" begin
                _, _ = DearDiary.create_userpermission(
                    user.id, project_id, false, true, false, false,
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
                    body=(
                        Dict(
                            "status_id" => (DearDiary.IN_PROGRESS |> Integer),
                            "name" => "Forbidden Experiment",
                        ) |> JSON.json
                    ),
                    status_exception=false,
                )
                @test create_response.status == HTTP.StatusCodes.FORBIDDEN
            end

            @testset "granting create permission allows POST" begin
                permission = DearDiary.get_userpermission(user.id, project_id)
                @test DearDiary.update_userpermission(
                    permission.id, true, nothing, nothing, nothing,
                ) isa DearDiary.Updated

                response = HTTP.post(
                    "http://127.0.0.1:9000/experiment/project/$(project_id)";
                    headers=user_headers,
                    body=(
                        Dict(
                            "status_id" => (DearDiary.IN_PROGRESS |> Integer),
                            "name" => "Allowed Experiment",
                        ) |> JSON.json
                    ),
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.CREATED
            end

            @testset "update and delete dispatch on the matching action" begin
                permission = DearDiary.get_userpermission(user.id, project_id)

                update_payload = Dict(
                    "status_id" => (DearDiary.STOPPED |> Integer),
                    "name" => nothing,
                    "description" => "edited",
                    "end_date" => nothing,
                ) |> JSON.json

                forbidden_update = HTTP.patch(
                    "http://127.0.0.1:9000/experiment/$(experiment_id)";
                    headers=user_headers,
                    body=update_payload,
                    status_exception=false,
                )
                @test forbidden_update.status == HTTP.StatusCodes.FORBIDDEN

                DearDiary.update_userpermission(
                    permission.id, nothing, nothing, true, nothing,
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
                    permission.id, nothing, nothing, nothing, true,
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
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Resolver Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Resolver Experiment",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            metric_id, _ = DearDiary.create_metric(iteration_id, "loss", 0.42)
            parameter_id, _ = DearDiary.create_parameter(iteration_id, "lr", "0.001")
            resource_id, _ = DearDiary.create_resource(
                experiment_id, "model.bin", UInt8[0x01, 0x02, 0x03],
            )

            req(target::AbstractString)::HTTP.Request = HTTP.Request("GET", target)

            @testset verbose = true "Iteration" begin
                @test DearDiary.get_project_id(
                    DearDiary.Iteration, req("/iteration/experiment/$(experiment_id)"),
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Iteration, req("/iteration/$(iteration_id)"),
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Iteration, req("/iteration/9999"),
                ) |> isnothing
                @test DearDiary.get_project_id(
                    DearDiary.Iteration, req("/iteration/experiment/9999"),
                ) |> isnothing
                @test DearDiary.get_project_id(
                    DearDiary.Iteration, req("/iteration/not-a-number"),
                ) |> isnothing
                @test DearDiary.get_project_id(
                    DearDiary.Iteration, req("/iteration"),
                ) |> isnothing
            end

            @testset verbose = true "Metric" begin
                @test DearDiary.get_project_id(
                    DearDiary.Metric, req("/metric/iteration/$(iteration_id)"),
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Metric, req("/metric/$(metric_id)"),
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Metric, req("/metric/9999"),
                ) |> isnothing
                @test DearDiary.get_project_id(
                    DearDiary.Metric, req("/metric/iteration/9999"),
                ) |> isnothing
                @test DearDiary.get_project_id(
                    DearDiary.Metric, req("/metric/not-a-number"),
                ) |> isnothing
            end

            @testset verbose = true "Parameter" begin
                @test DearDiary.get_project_id(
                    DearDiary.Parameter, req("/parameter/iteration/$(iteration_id)"),
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Parameter, req("/parameter/$(parameter_id)"),
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Parameter, req("/parameter/9999"),
                ) |> isnothing
                @test DearDiary.get_project_id(
                    DearDiary.Parameter, req("/parameter/iteration/9999"),
                ) |> isnothing
                @test DearDiary.get_project_id(
                    DearDiary.Parameter, req("/parameter/not-a-number"),
                ) |> isnothing
            end

            @testset verbose = true "Resource" begin
                @test DearDiary.get_project_id(
                    DearDiary.Resource, req("/resource/experiment/$(experiment_id)"),
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Resource, req("/resource/$(resource_id)"),
                ) == project_id
                @test DearDiary.get_project_id(
                    DearDiary.Resource, req("/resource/9999"),
                ) |> isnothing
                @test DearDiary.get_project_id(
                    DearDiary.Resource, req("/resource/experiment/9999"),
                ) |> isnothing
                @test DearDiary.get_project_id(
                    DearDiary.Resource, req("/resource/not-a-number"),
                ) |> isnothing
            end
        end
    end
end
