@with_trackingapi_test_db begin
    @testset verbose = true "experiment routes" begin
        @testset verbose = true "create experiment" begin
            project_payload = Dict("name" => "Test Project") |> JSON.json
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_data = JSON.parse(project_response.body |> String, Dict{String,Any})
            project_id = project_data["project_id"]

            payload = Dict(
                "status_id" => (TrackingAPI.IN_PROGRESS |> Integer),
                "name" => "Test Experiment",
            ) |> JSON.json
            response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["experiment_id"] == 1
        end

        @testset verbose = true "get experiment by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/experiment/1";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            experiment = data |> TrackingAPI.Experiment

            @test experiment.id isa Int
            @test experiment.project_id == 1
            @test experiment.status_id == (TrackingAPI.IN_PROGRESS |> Integer)
            @test experiment.name == "Test Experiment"
            @test experiment.description |> isempty
            @test experiment.created_date isa DateTime
        end

        @testset verbose = true "get experiments" begin
            payload = Dict(
                "status_id" => TrackingAPI.FINISHED |> Integer,
                "name" => "Second Experiment",
            ) |> JSON.json
            HTTP.post(
                "http://127.0.0.1:9000/experiment/project/1";
                body=payload,
                status_exception=false,
            )

            response = HTTP.get(
                "http://127.0.0.1:9000/experiment/project/1";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Array{Dict{String,Any},1})
            experiments = data .|> TrackingAPI.Experiment

            @test experiments isa Array{TrackingAPI.Experiment,1}
            @test (experiments |> length) == 2
        end

        @testset verbose = true "update experiment" begin
            payload = Dict(
                "status_id" => TrackingAPI.STOPPED |> Integer,
                "name" => nothing,
                "description" => "Updated experiment",
                "end_date" => nothing,
            ) |> JSON.json
            response = HTTP.patch(
                "http://127.0.0.1:9000/experiment/2";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/experiment/2";
                status_exception=false,
            )
            data = JSON.parse(response.body |> String, Dict{String,Any})
            experiment = data |> TrackingAPI.Experiment

            @test experiment.status_id == (TrackingAPI.STOPPED |> Integer)
            @test experiment.name == "Second Experiment"
            @test experiment.description == "Updated experiment"
        end

        @testset verbose = true "delete experiment" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/experiment/2";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "OK"
        end
    end
end
