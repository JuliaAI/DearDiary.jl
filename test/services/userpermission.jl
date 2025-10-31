@with_trackingapi_test_db begin
    @testset verbose = true "userpermission service" begin
        @testset verbose = true "create" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")

            @testset "create with no existing user" begin
                _, upsert_result = TrackingAPI.create_userpermission(
                    9999,
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa TrackingAPI.Unprocessable
            end

            @testset "create with no existing project" begin
                _, upsert_result = TrackingAPI.create_userpermission(
                    user.id,
                    9999,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa TrackingAPI.Unprocessable
            end

            @testset "create with existing user and project" begin
                new_user_id, _ = TrackingAPI.create_user("Gala", "Missy", "gala", "missy")
                userpermission_id, upsert_result = TrackingAPI.create_userpermission(
                    new_user_id,
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa TrackingAPI.Created
                @test userpermission_id isa Integer
            end

            @testset "create duplicate user permission" begin
                _, upsert_result = TrackingAPI.create_userpermission(
                    user.id,
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa TrackingAPI.Duplicate
            end
        end

        @testset verbose = true "get by user id and project id" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")

            @testset "get with existing user and project" begin
                userpermission = TrackingAPI.get_userpermission_by_user_and_project(
                    user.id,
                    project_id,
                )

                @test userpermission isa TrackingAPI.UserPermission
                @test userpermission.user_id == user.id
                @test userpermission.project_id == project_id
            end

            @testset "get with non-existing user" begin
                userpermission = TrackingAPI.get_userpermission_by_user_and_project(
                    9999,
                    project_id,
                )

                @test userpermission |> isnothing
            end

            @testset "get with non-existing project" begin
                userpermission = TrackingAPI.get_userpermission_by_user_and_project(
                    user.id,
                    9999,
                )

                @test userpermission |> isnothing
            end

            @testset "get with non-existing user and project" begin
                userpermission = TrackingAPI.get_userpermission_by_user_and_project(
                    9999,
                    9999,
                )

                @test userpermission |> isnothing
            end
        end

        @testset verbose = true "update" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")

            userpermission = TrackingAPI.get_userpermission_by_user_and_project(
                user.id,
                project_id,
            )
            @test userpermission.create_permission == false
            @test userpermission.read_permission == true
            @test userpermission.update_permission == false
            @test userpermission.delete_permission == false

            @test TrackingAPI.update_userpermission(
                userpermission.id,
                true,
                nothing,
                nothing,
                nothing,
            ) isa TrackingAPI.Updated
            userpermission = TrackingAPI.get_userpermission_by_user_and_project(
                user.id,
                project_id,
            )
            @test userpermission.create_permission == true
            @test userpermission.read_permission == true
            @test userpermission.update_permission == false
            @test userpermission.delete_permission == false
        end

        @testset verbose = true "delete" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            userpermission = TrackingAPI.get_userpermission_by_user_and_project(
                user.id,
                project_id,
            )

            @test TrackingAPI.delete_userpermission(userpermission.id)
            @test TrackingAPI.get_userpermission_by_user_and_project(
                user.id,
                project_id,
            ) |> isnothing
        end
    end
end
