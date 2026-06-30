@with_deardiary_test_db begin
    @testset verbose = true "project service" begin
        @testset verbose = true "create project" begin
            @testset verbose = true "with user_id as argument" begin
                user_id, _ = DearDiary.create_user("Missy", "Gala", "missy", "gala")
                DearDiary.update_user(user_id, nothing, nothing, nothing, true)
                project_id, project_upsert_result = DearDiary.create_project(
                    user_id, "Test Project"
                )

                @test project_upsert_result === DearDiary.Created
                @test project_id isa String
                @test !isempty(project_id)
            end

            @testset "with non-existing user_id as argument" begin
                project_id, project_upsert_result = DearDiary.create_project(
                    "00000000-0000-0000-0000-000000000000", "Test Project"
                )

                @test isnothing(project_id)
                @test project_upsert_result === DearDiary.Unprocessable
            end

            @testset "with non-admin user_id as argument" begin
                user_id, _ = DearDiary.create_user("Regular", "User", "regular", "user")
                project_id, project_upsert_result = DearDiary.create_project(
                    user_id, "Test Project"
                )

                @test isnothing(project_id)
                @test project_upsert_result === DearDiary.Unprocessable
            end

            @testset verbose = true "with no user_id as argument" begin
                project_id, project_upsert_result = DearDiary.create_project("Test Project")

                @test project_upsert_result === DearDiary.Created
                @test project_id isa String
                @test !isempty(project_id)

                default_user = DearDiary.get_user_by_username("default")

                userpermission = DearDiary.get_userpermission(default_user.id, project_id)
                @test !(isnothing(userpermission))
            end
        end

        @testset verbose = true "get project by id" begin
            @testset verbose = true "get project by existing id" begin
                first_project = DearDiary.get_projects()[1]
                project = DearDiary.get_project(first_project.id)
                @test project isa DearDiary.Project
                @test project.id == first_project.id
                @test project.name == "Test Project"
            end

            @testset verbose = true "get project by non-existing id" begin
                project = DearDiary.get_project("00000000-0000-0000-0000-000000000000")
                @test isnothing(project)
            end
        end

        @testset verbose = true "get projects" begin
            projects = DearDiary.get_projects()

            @test projects isa Array{DearDiary.Project,1}
            @test (length(projects)) == 2
            @test projects[1].name == "Test Project"
        end

        @testset verbose = true "update project" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_project(
                    "00000000-0000-0000-0000-000000000000",
                    "Updated Test Project",
                    "Updated Description",
                )

                @test result === DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                first_project = DearDiary.get_projects()[1]
                @test DearDiary.update_project(
                    first_project.id, "Updated Test Project", "Updated Description"
                ) === DearDiary.Updated

                project = DearDiary.get_project(first_project.id)

                @test project.name == "Updated Test Project"
                @test project.description == "Updated Description"
            end
        end

        @testset verbose = true "delete project" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Project to Delete")
            DearDiary.create_experiment(project_id, DearDiary.IN_PROGRESS, "Test")

            @test DearDiary.delete_project(project_id)
            @test isnothing(DearDiary.get_project(project_id))
        end
    end
end
