@with_tracking_test_db begin
    @testset verbose = true "project routes" begin
        @testset verbose = true "create project" begin
            payload = Dict("name" => "Missy project") |> JSON.json
            response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["project_id"] == 1
        end

        @testset verbose = true "get project by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/project/1";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            project = data |> Tracking.Project

            @test project.id isa Int
            @test project.name == "Missy project"
            @test project.description |> isempty
            @test project.created_date isa DateTime
        end

        @testset verbose = true "get projects" begin
            payload = Dict("name" => "Gala project") |> JSON.json
            HTTP.post(
                "http://127.0.0.1:9000/project";
                body=payload,
                status_exception=false,
            )

            response = HTTP.get("http://127.0.0.1:9000/project/"; status_exception=false)

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Array{Dict{String,Any},1})
            projects = data .|> Tracking.Project

            @test projects isa Array{Tracking.Project,1}
            @test (projects |> length) == 2
        end

        @testset verbose = true "update project" begin
            payload = Dict(
                "name" => nothing,
                "description" => "Updated project",
            ) |> JSON.json
            response = HTTP.patch(
                "http://127.0.0.1:9000/project/2";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get("http://127.0.0.1:9000/project/2"; status_exception=false)
            data = JSON.parse(response.body |> String, Dict{String,Any})
            project = data |> Tracking.Project

            @test project.name == "Gala project"
            @test project.description == "Updated project"
        end

        @testset verbose = true "delete project" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/project/2";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "OK"
        end
    end
end
