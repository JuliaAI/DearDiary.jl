@with_tracking_test_db begin
    @testset verbose = true "project service" begin
        @testset verbose = true "create project" begin
            @testset verbose = true "with user_id as argument" begin
                user_id, _ = Tracking.create_user("Missy", "Gala", "missy", "gala")
                Tracking.update_user(user_id, nothing, nothing, nothing, true)
                project_id, project_upsert_result = Tracking.create_project(
                    user_id,
                    "Test Project",
                )

                @test project_upsert_result isa Tracking.Created
                @test project_id isa Integer
            end

            @testset verbose = true "with no user_id as argument" begin
                project_id, project_upsert_result = Tracking.create_project(
                    "Test Project",
                )

                @test project_upsert_result isa Tracking.Created
                @test project_id isa Integer

                default_user = Tracking.get_user("default")

                userpermission = Tracking.get_userpermission(
                    default_user.id,
                    project_id,
                )
                @test !(userpermission |> isnothing)
            end
        end

        @testset verbose = true "get project by id" begin
            @testset verbose = true "get project by existing id" begin
                project = Tracking.get_project(1)
                @test project isa Tracking.Project
                @test project.id == 1
                @test project.name == "Test Project"
            end

            @testset verbose = true "get project by non-existing id" begin
                project = Tracking.get_project(9999)
                @test project |> isnothing
            end
        end

        @testset verbose = true "get projects" begin
            projects = Tracking.get_projects()

            @test projects isa Array{Tracking.Project,1}
            @test (projects |> length) == 2
            @test projects[1].id == 1
            @test projects[1].name == "Test Project"
        end

        @testset verbose = true "update project" begin
            @test Tracking.update_project(
                1,
                "Updated Test Project",
                "Updated Description"
            ) isa Tracking.Updated

            project = Tracking.get_project(1)

            @test project.name == "Updated Test Project"
            @test project.description == "Updated Description"
        end

        @testset verbose = true "delete project" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Project to Delete")

            @test Tracking.delete_project(project_id)
            @test Tracking.get_project(project_id) |> isnothing
        end
    end
end
