@with_tracking_test_db begin
    @testset verbose = true "userpermission service" begin
        @testset verbose = true "create" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")

            @testset "create with no existing user" begin
                _, upsert_result = Tracking.create_userpermission(
                    9999,
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa Tracking.Unprocessable
            end

            @testset "create with no existing project" begin
                _, upsert_result = Tracking.create_userpermission(
                    user.id,
                    9999,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa Tracking.Unprocessable
            end

            @testset "create with existing user and project" begin
                new_user_id, _ = Tracking.create_user("Gala", "Missy", "gala", "missy")
                userpermission_id, upsert_result = Tracking.create_userpermission(
                    new_user_id,
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa Tracking.Created
                @test userpermission_id isa Integer
            end

            @testset "create duplicate user permission" begin
                _, upsert_result = Tracking.create_userpermission(
                    user.id,
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa Tracking.Duplicate
            end
        end

        @testset verbose = true "get by user id and project id" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")

            @testset "get with existing user and project" begin
                userpermission = Tracking.get_userpermission(
                    user.id,
                    project_id,
                )

                @test userpermission isa Tracking.UserPermission
                @test userpermission.user_id == user.id
                @test userpermission.project_id == project_id
            end

            @testset "get with non-existing user" begin
                userpermission = Tracking.get_userpermission(
                    9999,
                    project_id,
                )

                @test userpermission |> isnothing
            end

            @testset "get with non-existing project" begin
                userpermission = Tracking.get_userpermission(user.id, 9999)

                @test userpermission |> isnothing
            end

            @testset "get with non-existing user and project" begin
                userpermission = Tracking.get_userpermission(9999, 9999)

                @test userpermission |> isnothing
            end
        end

        @testset verbose = true "update" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")

            userpermission = Tracking.get_userpermission(user.id, project_id)
            @test userpermission.create_permission == false
            @test userpermission.read_permission == true
            @test userpermission.update_permission == false
            @test userpermission.delete_permission == false

            @test Tracking.update_userpermission(
                userpermission.id,
                true,
                nothing,
                nothing,
                nothing,
            ) isa Tracking.Updated
            userpermission = Tracking.get_userpermission(user.id, project_id)
            @test userpermission.create_permission == true
            @test userpermission.read_permission == true
            @test userpermission.update_permission == false
            @test userpermission.delete_permission == false
        end

        @testset verbose = true "delete" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            userpermission = Tracking.get_userpermission(user.id, project_id)

            @test Tracking.delete_userpermission(userpermission.id)
            @test Tracking.get_userpermission(user.id, project_id) |> isnothing
        end
    end
end
