@with_deardiary_test_db begin
    @testset verbose = true "project service" begin
        @testset verbose = true "create project" begin
            @testset verbose = true "with user_id as argument" begin
                user_id, _ = DearDiary.create_user("Missy", "Gala", "missy", "gala")
                DearDiary.update_user(user_id, nothing, nothing, nothing, true)
                project_id, project_upsert_result = DearDiary.create_project(
                    user_id,
                    "Test Project",
                )

                @test project_upsert_result === DearDiary.Created
                @test project_id isa Integer
            end

            @testset "with non-existing user_id as argument" begin
                project_id, project_upsert_result = DearDiary.create_project(
                    9999,
                    "Test Project",
                )

                @test project_id |> isnothing
                @test project_upsert_result === DearDiary.Unprocessable
            end

            @testset "with non-admin user_id as argument" begin
                user_id, _ = DearDiary.create_user("Regular", "User", "regular", "user")
                project_id, project_upsert_result = DearDiary.create_project(
                    user_id,
                    "Test Project",
                )

                @test project_id |> isnothing
                @test project_upsert_result === DearDiary.Unprocessable
            end

            @testset verbose = true "with no user_id as argument" begin
                project_id, project_upsert_result = DearDiary.create_project(
                    "Test Project",
                )

                @test project_upsert_result === DearDiary.Created
                @test project_id isa Integer

                default_user = DearDiary.get_user("default")

                userpermission = DearDiary.get_userpermission(
                    default_user.id,
                    project_id,
                )
                @test !(userpermission |> isnothing)
            end
        end

        @testset verbose = true "get project by id" begin
            @testset verbose = true "get project by existing id" begin
                project = DearDiary.get_project(1)
                @test project isa DearDiary.Project
                @test project.id == 1
                @test project.name == "Test Project"
            end

            @testset verbose = true "get project by non-existing id" begin
                project = DearDiary.get_project(9999)
                @test project |> isnothing
            end
        end

        @testset verbose = true "get projects" begin
            projects = DearDiary.get_projects()

            @test projects isa Array{DearDiary.Project,1}
            @test (projects |> length) == 2
            @test projects[1].id == 1
            @test projects[1].name == "Test Project"
        end

        @testset verbose = true "update project" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_project(
                    9999,
                    "Updated Test Project",
                    "Updated Description"
                )

                @test result === DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                @test DearDiary.update_project(
                    1,
                    "Updated Test Project",
                    "Updated Description"
                ) === DearDiary.Updated

                project = DearDiary.get_project(1)

                @test project.name == "Updated Test Project"
                @test project.description == "Updated Description"
            end
        end

        @testset verbose = true "delete project" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Project to Delete")
            DearDiary.create_experiment(project_id, DearDiary.IN_PROGRESS, "Test")

            @test DearDiary.delete_project(project_id)
            @test DearDiary.get_project(project_id) |> isnothing
        end
    end
end
