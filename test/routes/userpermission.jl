@with_deardiary_test_db begin
    @testset verbose = true "userpermission routes" begin
        @testset verbose = true "create" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            new_user_id, _ = DearDiary.create_user("Choclo", "Dokie", "choclo", "dokie")
            payload = JSON.json(
                Dict(
                    "create_permission" => true,
                    "read_permission" => true,
                    "update_permission" => false,
                    "delete_permission" => false,
                ),
            )

            response = HTTP.post(
                "http://127.0.0.1:9000/userpermission/user/$(new_user_id)/project/$(project_id)";
                body=payload,
                status_exception=false,
            )

            userpermission = DearDiary.get_userpermission(new_user_id, project_id)

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["userpermission_id"] == userpermission.id
        end

        @testset verbose = true "get by user id and project id" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            new_user_id, _ = DearDiary.create_user("Dokie", "Choclo", "dokie", "choclo")
            userpermission_id, _ = DearDiary.create_userpermission(
                new_user_id, project_id, false, true, false, false
            )

            response = HTTP.get(
                "http://127.0.1:9000/userpermission/user/$(new_user_id)/project/$(project_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK

            data = JSON.parse(String(response.body), Dict{String,Any})
            userpermission = DearDiary.UserPermission(data)

            @test userpermission.id == userpermission_id
            @test userpermission.user_id == new_user_id
            @test userpermission.project_id == project_id
            @test userpermission.create_permission == false
            @test userpermission.read_permission == true
            @test userpermission.update_permission == false
            @test userpermission.delete_permission == false
        end

        @testset verbose = true "update" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            new_user_id, _ = DearDiary.create_user("Ana", "Missy", "ana", "missy")
            userpermission_id, _ = DearDiary.create_userpermission(
                new_user_id, project_id, false, true, false, false
            )

            payload = JSON.json(
                Dict(
                    "create_permission" => true,
                    "read_permission" => true,
                    "update_permission" => true,
                    "delete_permission" => false,
                ),
            )

            response = HTTP.patch(
                "http://127.0.1:9000/userpermission/$(userpermission_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "UPDATED"

            userpermission = DearDiary.get_userpermission(new_user_id, project_id)

            @test userpermission.create_permission == true
            @test userpermission.read_permission == true
            @test userpermission.update_permission == true
            @test userpermission.delete_permission == false
        end

        @testset verbose = true "delete" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            new_user_id, _ = DearDiary.create_user("Galinha", "Ana", "galinha", "ana")
            userpermission_id, _ = DearDiary.create_userpermission(
                new_user_id, project_id, false, true, false, false
            )

            response = HTTP.delete(
                "http://127.0.1:9000/userpermission/$(userpermission_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "OK"

            userpermission = DearDiary.get_userpermission(new_user_id, project_id)

            @test isnothing(userpermission)
        end
    end
end
