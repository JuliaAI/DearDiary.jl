@with_deardiary_test_db begin
    @testset verbose = true "user permission repository" begin
        @testset verbose = true "insert" begin
            user = DearDiary.fetch_by_username(DearDiary.User, "default")
            project_id, _ = DearDiary.insert(DearDiary.Project, "Test Project")

            @testset "insert with no existing user" begin
                id, status = DearDiary.insert(
                    DearDiary.UserPermission,
                    "00000000-0000-0000-0000-000000000000",
                    project_id,
                )
                @test isnothing(id)
                @test status === DearDiary.Unprocessable
            end

            @testset "insert with no existing project" begin
                id, status = DearDiary.insert(
                    DearDiary.UserPermission,
                    user.id,
                    "00000000-0000-0000-0000-000000000000",
                )
                @test isnothing(id)
                @test status === DearDiary.Unprocessable
            end

            @testset "insert with existing user and project" begin
                id, status = DearDiary.insert(DearDiary.UserPermission, user.id, project_id)
                @test id isa String
                @test !isempty(id)
                @test status === DearDiary.Created
            end

            @testset "insert duplicate user permission" begin
                id, status = DearDiary.insert(DearDiary.UserPermission, user.id, project_id)
                @test isnothing(id)
                @test status === DearDiary.Duplicate
            end
        end

        @testset verbose = true "fetch" begin
            user = DearDiary.fetch_by_username(DearDiary.User, "default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")

            @testset "fetch with existing user and project" begin
                userpermission = DearDiary.fetch(
                    DearDiary.UserPermission, user.id, project_id
                )

                @test userpermission isa DearDiary.UserPermission
                @test userpermission.user_id == user.id
                @test userpermission.project_id == project_id
            end

            @testset "fetch with non-existing user" begin
                userpermission = DearDiary.fetch(
                    DearDiary.UserPermission,
                    "00000000-0000-0000-0000-000000000000",
                    project_id,
                )

                @test isnothing(userpermission)
            end

            @testset "fetch with non-existing project" begin
                userpermission = DearDiary.fetch(
                    DearDiary.UserPermission,
                    user.id,
                    "00000000-0000-0000-0000-000000000000",
                )

                @test isnothing(userpermission)
            end

            @testset "fetch with non-existing user and project" begin
                userpermission = DearDiary.fetch(
                    DearDiary.UserPermission,
                    "00000000-0000-0000-0000-000000000000",
                    "00000000-0000-0000-0000-000000000000",
                )

                @test isnothing(userpermission)
            end
        end

        @testset verbose = true "update" begin
            user = DearDiary.fetch_by_username(DearDiary.User, "default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")

            userpermission = DearDiary.fetch(DearDiary.UserPermission, user.id, project_id)
            @test userpermission.create_permission == false

            @test DearDiary.update(
                DearDiary.UserPermission, userpermission.id; create_permission=true
            ) === DearDiary.Updated

            userpermission = DearDiary.fetch(DearDiary.UserPermission, user.id, project_id)
            @test userpermission.create_permission
        end

        @testset verbose = true "delete" begin
            user = DearDiary.fetch_by_username(DearDiary.User, "default")

            @testset verbose = true "delete using userpermission id" begin
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                userpermission = DearDiary.fetch(
                    DearDiary.UserPermission, user.id, project_id
                )

                @test DearDiary.delete(DearDiary.UserPermission, userpermission.id)
                @test isnothing(
                    DearDiary.fetch(DearDiary.UserPermission, user.id, project_id)
                )
            end

            @testset verbose = true "delete using project" begin
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                project = DearDiary.fetch(DearDiary.Project, project_id)

                @test DearDiary.delete(DearDiary.UserPermission, project)
                @test isnothing(
                    DearDiary.fetch(DearDiary.UserPermission, user.id, project.id)
                )
            end

            @testset verbose = true "delete using user" begin
                project_id, _ = DearDiary.create_project(user.id, "Test Project")

                @test DearDiary.delete(DearDiary.UserPermission, user)
                @test isnothing(
                    DearDiary.fetch(DearDiary.UserPermission, user.id, project_id)
                )
            end
        end
    end
end
