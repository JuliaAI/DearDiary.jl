@with_trackingapi_test_db begin
    @testset verbose = true "user permission repository" begin
        @testset verbose = true "insert" begin
            user = TrackingAPI.fetch(TrackingAPI.User, "default")
            project_id, _ = TrackingAPI.insert(TrackingAPI.Project, "Test Project")

            @testset "insert with no existing user" begin
                @test TrackingAPI.insert(
                    TrackingAPI.UserPermission,
                    9999,
                    project_id,
                ) isa Tuple{Nothing,TrackingAPI.Unprocessable}
            end

            @testset "insert with no existing project" begin
                @test TrackingAPI.insert(
                    TrackingAPI.UserPermission,
                    user.id,
                    9999,
                ) isa Tuple{Nothing,TrackingAPI.Unprocessable}
            end

            @testset "insert with existing user and project" begin
                @test TrackingAPI.insert(
                    TrackingAPI.UserPermission,
                    user.id,
                    project_id,
                ) isa Tuple{Integer,TrackingAPI.Created}
            end

            @testset "insert duplicate user permission" begin
                @test TrackingAPI.insert(
                    TrackingAPI.UserPermission,
                    user.id,
                    project_id,
                ) isa Tuple{Nothing,TrackingAPI.Duplicate}
            end
        end

        @testset verbose = true "fetch" begin
            user = TrackingAPI.fetch(TrackingAPI.User, "default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")

            @testset "fetch with existing user and project" begin
                userpermission = TrackingAPI.fetch(
                    TrackingAPI.UserPermission,
                    user.id,
                    project_id,
                )

                @test userpermission isa TrackingAPI.UserPermission
                @test userpermission.user_id == user.id
                @test userpermission.project_id == project_id
            end

            @testset "fetch with non-existing user" begin
                userpermission = TrackingAPI.fetch(
                    TrackingAPI.UserPermission,
                    9999,
                    project_id,
                )

                @test userpermission |> isnothing
            end

            @testset "fetch with non-existing project" begin
                userpermission = TrackingAPI.fetch(
                    TrackingAPI.UserPermission,
                    user.id,
                    9999,
                )

                @test userpermission |> isnothing
            end

            @testset "fetch with non-existing user and project" begin
                userpermission = TrackingAPI.fetch(TrackingAPI.UserPermission, 9999, 9999)

                @test userpermission |> isnothing
            end
        end

        @testset verbose = true "update" begin
            user = TrackingAPI.fetch(TrackingAPI.User, "default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")

            userpermission = TrackingAPI.fetch(
                TrackingAPI.UserPermission,
                user.id,
                project_id,
            )
            @test userpermission.create_permission == false

            @test TrackingAPI.update(
                TrackingAPI.UserPermission, userpermission.id;
                create_permission=true,
            ) isa TrackingAPI.Updated

            userpermission = TrackingAPI.fetch(
                TrackingAPI.UserPermission,
                user.id,
                project_id,
            )
            @test userpermission.create_permission
        end

        @testset verbose = true "delete" begin
            user = TrackingAPI.fetch(TrackingAPI.User, "default")

            @testset verbose = true "delete using userpermission id" begin
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                userpermission = TrackingAPI.fetch(
                    TrackingAPI.UserPermission,
                    user.id,
                    project_id,
                )

                @test TrackingAPI.delete(TrackingAPI.UserPermission, userpermission.id)
                @test TrackingAPI.fetch(
                    TrackingAPI.UserPermission,
                    user.id,
                    project_id,
                ) |> isnothing
            end

            @testset verbose = true "delete using project" begin
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                project = TrackingAPI.fetch(TrackingAPI.Project, project_id)

                @test TrackingAPI.delete(TrackingAPI.UserPermission, project)
                @test TrackingAPI.fetch(
                    TrackingAPI.UserPermission,
                    user.id,
                    project.id,
                ) |> isnothing
            end

            @testset verbose = true "delete using user" begin
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")

                @test TrackingAPI.delete(TrackingAPI.UserPermission, user)
                @test TrackingAPI.fetch(
                    TrackingAPI.UserPermission,
                    user.id,
                    project_id,
                ) |> isnothing
            end
        end
    end
end
