@with_tracking_test_db begin
    @testset verbose = true "project repository" begin
        @testset verbose = true "insert" begin
            @test Tracking.insert(
                Tracking.Project,
                "Project Missy",
            ) isa Tuple{Integer,Tracking.Created}
        end

        @testset verbose = true "fetch" begin
            project = Tracking.fetch(Tracking.Project, 1)

            @test project isa Tracking.Project
            @test project.id == 1
            @test project.name == "Project Missy"
            @test project.description |> isempty
            @test project.created_date isa DateTime
        end

        @testset verbose = true "fetch all" begin
            Tracking.insert(Tracking.Project, "Project Gala")

            projects = Tracking.Project |> Tracking.fetch_all

            @test projects isa Array{Tracking.Project,1}
            @test (projects |> length) == 2
        end

        @testset verbose = true "update" begin
            @test Tracking.update(
                Tracking.Project, 1;
                name="Project Choclo",
                description="Updated project"
            ) isa Tracking.Updated

            project = Tracking.fetch(Tracking.Project, 1)

            @test project.name == "Project Choclo"
            @test project.description == "Updated project"
        end

        @testset verbose = true "delete" begin
            @test Tracking.delete(Tracking.Project, 1)
            @test Tracking.fetch(Tracking.Project, 1) |> isnothing
        end
    end
end
