@with_trackingapi_test_db begin
    @testset verbose = true "iteration routes" begin
        @testset verbose = true "create iteration" begin
            project_payload = Dict("name" => "Iteration Project") |> JSON.json
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_data = JSON.parse(project_response.body |> String, Dict{String,Any})
            project_id = project_data["project_id"]

            experiment_payload = Dict(
                "status_id" => (TrackingAPI.IN_PROGRESS |> Integer),
                "name" => "Experiment for Iterations",
            ) |> JSON.json
            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=experiment_payload,
                status_exception=false,
            )
            experiment_data = JSON.parse(
                experiment_response.body |> String,
                Dict{String,Any},
            )
            experiment_id = experiment_data["experiment_id"]

            response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["iteration_id"] == 1
        end

        @testset verbose = true "get iteration by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/iteration/1";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            iteration = data |> TrackingAPI.Iteration

            @test iteration.id isa Int
            @test iteration.experiment_id == 1
            @test iteration.notes |> isempty
            @test iteration.created_date isa DateTime
        end

        @testset verbose = true "get iterations" begin
            HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/1";
                status_exception=false,
            )

            response = HTTP.get(
                "http://127.0.0.1:9000/iteration/experiment/1";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Array{Dict{String,Any},1})
            iterations = data .|> TrackingAPI.Iteration

            @test iterations isa Array{TrackingAPI.Iteration,1}
            @test (iterations |> length) == 2
        end

        @testset verbose = true "update iteration" begin
            payload = Dict(
                "notes" => "Updated notes for iteration",
                "end_date" => nothing,
            ) |> JSON.json
            response = HTTP.patch(
                "http://127.0.0.1:9000/iteration/2";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/iteration/2";
                status_exception=false,
            )
            data = JSON.parse(response.body |> String, Dict{String,Any})
            iteration = data |> TrackingAPI.Iteration

            @test iteration.notes == "Updated notes for iteration"
        end

        @testset verbose = true "delete iteration" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/iteration/2";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "OK"
        end
    end
end
