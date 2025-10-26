@with_trackingapi_test_db begin
    @testset verbose = true "project service" begin
        @testset verbose = true "create project" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, project_upsert_result = TrackingAPI.create_project(user.id, TrackingAPI.ProjectCreatePayload("Test Project"))

            @test project_upsert_result isa TrackingAPI.Created
            @test project_id isa Integer
        end

        @testset verbose = true "get project by id" begin
            @testset verbose = true "get project by existing id" begin
                project = TrackingAPI.get_project_by_id(1)
                @test project isa TrackingAPI.Project
                @test project.id == 1
                @test project.name == "Test Project"
            end

            @testset verbose = true "get project by non-existing id" begin
                project = TrackingAPI.get_project_by_id(9999)
                @test project |> isnothing
            end
        end

        @testset verbose = true "get projects" begin
            projects = TrackingAPI.get_projects()

            @test projects isa Array{TrackingAPI.Project,1}
            @test (projects |> length) == 1
            @test projects[1].id == 1
            @test projects[1].name == "Test Project"
        end

        @testset verbose = true "update project" begin
            project_payload = TrackingAPI.ProjectUpdatePayload("Updated Test Project", "Updated Description")
            @test TrackingAPI.update_project(1, project_payload) isa TrackingAPI.Updated

            project = TrackingAPI.get_project_by_id(1)

            @test project.name == "Updated Test Project"
            @test project.description == "Updated Description"
        end

        @testset verbose = true "delete project" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, TrackingAPI.ProjectCreatePayload("Project to Delete"))
            @test TrackingAPI.delete_project(project_id)

            @test TrackingAPI.get_project_by_id(project_id) |> isnothing
        end
    end
end
