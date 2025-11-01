@with_tracking_test_db begin
    @testset verbose = true "userpermission routes" begin
        @testset verbose = true "create" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            new_user_id, _ = Tracking.create_user("Choclo", "Dokie", "choclo", "dokie")
            payload = Dict(
                "create_permission" => true,
                "read_permission" => true,
                "update_permission" => false,
                "delete_permission" => false,
            ) |> JSON.json

            response = HTTP.post(
                "http://127.0.0.1:9000/userpermission/user/$(new_user_id)/project/$(project_id)";
                body=payload,
                status_exception=false,
            )

            userpermission = Tracking.get_userpermission(new_user_id, project_id)

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["userpermission_id"] == userpermission.id
        end

        @testset verbose = true "get by user id and project id" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            new_user_id, _ = Tracking.create_user("Dokie", "Choclo", "dokie", "choclo")
            userpermission_id, _ = Tracking.create_userpermission(
                new_user_id,
                project_id,
                false,
                true,
                false,
                false,
            )

            response = HTTP.get(
                "http://127.0.1:9000/userpermission/user/$(new_user_id)/project/$(project_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK

            data = JSON.parse(response.body |> String, Dict{String,Any})
            userpermission = data |> Tracking.UserPermission

            @test userpermission.id == userpermission_id
            @test userpermission.user_id == new_user_id
            @test userpermission.project_id == project_id
            @test userpermission.create_permission == false
            @test userpermission.read_permission == true
            @test userpermission.update_permission == false
            @test userpermission.delete_permission == false
        end

        @testset verbose = true "update" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            new_user_id, _ = Tracking.create_user("Ana", "Missy", "ana", "missy")
            userpermission_id, _ = Tracking.create_userpermission(
                new_user_id,
                project_id,
                false,
                true,
                false,
                false,
            )

            payload = Dict(
                "create_permission" => true,
                "read_permission" => true,
                "update_permission" => true,
                "delete_permission" => false,
            ) |> JSON.json

            response = HTTP.patch(
                "http://127.0.1:9000/userpermission/$(userpermission_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "UPDATED"

            userpermission = Tracking.get_userpermission(new_user_id, project_id)

            @test userpermission.create_permission == true
            @test userpermission.read_permission == true
            @test userpermission.update_permission == true
            @test userpermission.delete_permission == false
        end

        @testset verbose = true "delete" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            new_user_id, _ = Tracking.create_user("Galinha", "Ana", "galinha", "ana")
            userpermission_id, _ = Tracking.create_userpermission(
                new_user_id,
                project_id,
                false,
                true,
                false,
                false,
            )

            response = HTTP.delete(
                "http://127.0.1:9000/userpermission/$(userpermission_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "OK"

            userpermission = Tracking.get_userpermission(new_user_id, project_id)

            @test userpermission |> isnothing
        end
    end
end
