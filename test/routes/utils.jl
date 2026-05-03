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
                token = JSON.parse(response.body |> String)

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
                token = JSON.parse(response.body |> String)

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

        @testset verbose = true "project permission middleware" begin
            admin_token = JSON.parse(
                HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=(
                        Dict("username" => "default", "password" => "default") |> JSON.json
                    ),
                    status_exception=false,
                ).body |> String,
            )
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
            )
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
    end
end
