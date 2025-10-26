@with_trackingapi_test_db begin
    @testset verbose = true "project repository" begin
        @testset verbose = true "insert" begin
            @test TrackingAPI.insert(TrackingAPI.Project, "Project Missy") isa Tuple{Integer,TrackingAPI.Created}
        end

        @testset verbose = true "fetch" begin
            project = TrackingAPI.fetch(TrackingAPI.Project, 1)

            @test project isa TrackingAPI.Project
            @test project.id == 1
            @test project.name == "Project Missy"
            @test project.description |> isempty
            @test project.created_date isa DateTime
        end

        @testset verbose = true "fetch all" begin
            TrackingAPI.insert(TrackingAPI.Project, "Project Gala")

            projects = TrackingAPI.Project |> TrackingAPI.fetch_all

            @test projects isa Array{TrackingAPI.Project,1}
            @test (projects |> length) == 2
        end

        @testset verbose = true "update" begin
            @test TrackingAPI.update(TrackingAPI.Project, 1; name="Project Choclo", description="Updated project") isa TrackingAPI.Updated

            project = TrackingAPI.fetch(TrackingAPI.Project, 1)

            @test project.name == "Project Choclo"
            @test project.description == "Updated project"
        end

        @testset verbose = true "delete" begin
            @test TrackingAPI.delete(TrackingAPI.Project, 1)
            @test TrackingAPI.fetch(TrackingAPI.Project, 1) |> isnothing
        end
    end
end
