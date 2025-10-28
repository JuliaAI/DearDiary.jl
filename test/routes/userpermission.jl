@with_trackingapi_test_db begin
    @testset verbose = true "userpermission routes" begin
        @testset verbose = true "create" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, TrackingAPI.ProjectCreatePayload("Missy Project"))
            new_user_id, _ = TrackingAPI.create_user(TrackingAPI.UserCreatePayload("Choclo", "Dokie", "choclo", "dokie"))
            payload = Dict(
                "create_permission" => true,
                "read_permission" => true,
                "update_permission" => false,
                "delete_permission" => false
            ) |> JSON.json

            response = HTTP.post("http://127.0.0.1:9000/userpermission/user/$(new_user_id)/project/$(project_id)"; body=payload, status_exception=false)

            userpermission = TrackingAPI.get_userpermission_by_user_and_project(new_user_id, project_id)

            @test response.status == HTTP.StatusCodes.CREATED
            data = response.body |> String |> JSON.parse
            @test data["userpermission_id"] == userpermission.id
        end

        @testset verbose = true "get by user id and project id" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, TrackingAPI.ProjectCreatePayload("Gala Project"))
            new_user_id, _ = TrackingAPI.create_user(TrackingAPI.UserCreatePayload("Dokie", "Choclo", "dokie", "choclo"))
            userpermission_id, _ = TrackingAPI.create_userpermission(new_user_id, project_id, TrackingAPI.UserPermissionCreatePayload(false, true, false, false))

            response = HTTP.get("http://127.0.1:9000/userpermission/user/$(new_user_id)/project/$(project_id)"; status_exception=false)

            @test response.status == HTTP.StatusCodes.OK

            data = response.body |> String |> JSON.parse
            userpermission = data |> TrackingAPI.UserPermission

            @test userpermission.id == userpermission_id
            @test userpermission.user_id == new_user_id
            @test userpermission.project_id == project_id
            @test userpermission.create_permission == false
            @test userpermission.read_permission == true
            @test userpermission.update_permission == false
            @test userpermission.delete_permission == false
        end

        @testset verbose = true "update" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, TrackingAPI.ProjectCreatePayload("Ana Project"))
            new_user_id, _ = TrackingAPI.create_user(TrackingAPI.UserCreatePayload("Ana", "Missy", "ana", "missy"))
            userpermission_id, _ = TrackingAPI.create_userpermission(new_user_id, project_id, TrackingAPI.UserPermissionCreatePayload(false, true, false, false))

            payload = Dict(
                "create_permission" => true,
                "read_permission" => true,
                "update_permission" => true,
                "delete_permission" => false
            ) |> JSON.json

            response = HTTP.patch("http://127.0.1:9000/userpermission/$(userpermission_id)"; body=payload, status_exception=false)

            @test response.status == HTTP.StatusCodes.OK
            data = response.body |> String |> JSON.parse
            @test data["message"] == "UPDATED"

            userpermission = TrackingAPI.get_userpermission_by_user_and_project(new_user_id, project_id)

            @test userpermission.create_permission == true
            @test userpermission.read_permission == true
            @test userpermission.update_permission == true
            @test userpermission.delete_permission == false
        end

        @testset verbose = true "delete" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, TrackingAPI.ProjectCreatePayload("Galinha Project"))
            new_user_id, _ = TrackingAPI.create_user(TrackingAPI.UserCreatePayload("Galinha", "Ana", "galinha", "ana"))
            userpermission_id, _ = TrackingAPI.create_userpermission(new_user_id, project_id, TrackingAPI.UserPermissionCreatePayload(false, true, false, false))

            response = HTTP.delete("http://127.0.1:9000/userpermission/$(userpermission_id)"; status_exception=false)

            @test response.status == HTTP.StatusCodes.OK
            data = response.body |> String |> JSON.parse
            @test data["message"] == "OK"

            userpermission = TrackingAPI.get_userpermission_by_user_and_project(new_user_id, project_id)

            @test userpermission |> isnothing
        end
    end
end
