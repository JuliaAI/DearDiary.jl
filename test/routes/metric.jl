@with_tracking_test_db begin
    @testset verbose = true "metric routes" begin
        @testset verbose = true "create metric" begin
            project_payload = Dict("name" => "Metric Project") |> JSON.json
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_data = JSON.parse(project_response.body |> String, Dict{String,Any})
            project_id = project_data["project_id"]

            experiment_payload = Dict(
                "status_id" => (Tracking.IN_PROGRESS |> Integer),
                "name" => "Experiment for Metrics",
            ) |> JSON.json
            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=experiment_payload,
                status_exception=false,
            )
            experiment_data = JSON.parse(experiment_response.body |> String, Dict{String,Any})
            experiment_id = experiment_data["experiment_id"]

            iteration_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )
            iteration_data = JSON.parse(iteration_response.body |> String, Dict{String,Any})
            iteration_id = iteration_data["iteration_id"]

            payload = Dict("key" => "accuracy", "value" => 0.92) |> JSON.json
            response = HTTP.post(
                "http://127.0.0.1:9000/metric/iteration/$(iteration_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["metric_id"] == 1
        end

        @testset verbose = true "get metric by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/metric/1";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            metric = data |> Tracking.Metric

            @test metric.id isa Int
            @test metric.iteration_id == 1
            @test metric.key == "accuracy"
            @test metric.value == 0.92
        end

        @testset verbose = true "get metrics" begin
            payload = Dict("key" => "loss", "value" => 0.15) |> JSON.json
            HTTP.post(
                "http://127.0.0.1:9000/metric/iteration/1";
                body=payload,
                status_exception=false,
            )

            response = HTTP.get(
                "http://127.0.0.1:9000/metric/iteration/1";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Array{Dict{String,Any},1})
            metrics = data .|> Tracking.Metric

            @test metrics isa Array{Tracking.Metric,1}
            @test (metrics |> length) == 2
        end

        @testset verbose = true "update metric" begin
            payload = Dict(
                "key" => "loss",
                "value" => 0.10,
            ) |> JSON.json
            response = HTTP.patch(
                "http://127.0.0.1:9000/metric/2";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/metric/2";
                status_exception=false,
            )
            data = JSON.parse(response.body |> String, Dict{String,Any})
            metric = data |> Tracking.Metric

            @test metric.key == "loss"
            @test metric.value == 0.10
        end

        @testset verbose = true "delete metric" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/metric/2";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "OK"
        end
    end
end
