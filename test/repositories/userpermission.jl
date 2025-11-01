@with_tracking_test_db begin
    @testset verbose = true "user permission repository" begin
        @testset verbose = true "insert" begin
            user = Tracking.fetch(Tracking.User, "default")
            project_id, _ = Tracking.insert(Tracking.Project, "Test Project")

            @testset "insert with no existing user" begin
                @test Tracking.insert(
                    Tracking.UserPermission,
                    9999,
                    project_id,
                ) isa Tuple{Nothing,Tracking.Unprocessable}
            end

            @testset "insert with no existing project" begin
                @test Tracking.insert(
                    Tracking.UserPermission,
                    user.id,
                    9999,
                ) isa Tuple{Nothing,Tracking.Unprocessable}
            end

            @testset "insert with existing user and project" begin
                @test Tracking.insert(
                    Tracking.UserPermission,
                    user.id,
                    project_id,
                ) isa Tuple{Integer,Tracking.Created}
            end

            @testset "insert duplicate user permission" begin
                @test Tracking.insert(
                    Tracking.UserPermission,
                    user.id,
                    project_id,
                ) isa Tuple{Nothing,Tracking.Duplicate}
            end
        end

        @testset verbose = true "fetch" begin
            user = Tracking.fetch(Tracking.User, "default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")

            @testset "fetch with existing user and project" begin
                userpermission = Tracking.fetch(
                    Tracking.UserPermission,
                    user.id,
                    project_id,
                )

                @test userpermission isa Tracking.UserPermission
                @test userpermission.user_id == user.id
                @test userpermission.project_id == project_id
            end

            @testset "fetch with non-existing user" begin
                userpermission = Tracking.fetch(
                    Tracking.UserPermission,
                    9999,
                    project_id,
                )

                @test userpermission |> isnothing
            end

            @testset "fetch with non-existing project" begin
                userpermission = Tracking.fetch(
                    Tracking.UserPermission,
                    user.id,
                    9999,
                )

                @test userpermission |> isnothing
            end

            @testset "fetch with non-existing user and project" begin
                userpermission = Tracking.fetch(Tracking.UserPermission, 9999, 9999)

                @test userpermission |> isnothing
            end
        end

        @testset verbose = true "update" begin
            user = Tracking.fetch(Tracking.User, "default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")

            userpermission = Tracking.fetch(
                Tracking.UserPermission,
                user.id,
                project_id,
            )
            @test userpermission.create_permission == false

            @test Tracking.update(
                Tracking.UserPermission, userpermission.id;
                create_permission=true,
            ) isa Tracking.Updated

            userpermission = Tracking.fetch(
                Tracking.UserPermission,
                user.id,
                project_id,
            )
            @test userpermission.create_permission
        end

        @testset verbose = true "delete" begin
            user = Tracking.fetch(Tracking.User, "default")

            @testset verbose = true "delete using userpermission id" begin
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                userpermission = Tracking.fetch(
                    Tracking.UserPermission,
                    user.id,
                    project_id,
                )

                @test Tracking.delete(Tracking.UserPermission, userpermission.id)
                @test Tracking.fetch(
                    Tracking.UserPermission,
                    user.id,
                    project_id,
                ) |> isnothing
            end

            @testset verbose = true "delete using project" begin
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                project = Tracking.fetch(Tracking.Project, project_id)

                @test Tracking.delete(Tracking.UserPermission, project)
                @test Tracking.fetch(
                    Tracking.UserPermission,
                    user.id,
                    project.id,
                ) |> isnothing
            end

            @testset verbose = true "delete using user" begin
                project_id, _ = Tracking.create_project(user.id, "Test Project")

                @test Tracking.delete(Tracking.UserPermission, user)
                @test Tracking.fetch(
                    Tracking.UserPermission,
                    user.id,
                    project_id,
                ) |> isnothing
            end
        end
    end
end
