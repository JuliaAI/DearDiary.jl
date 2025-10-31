@with_trackingapi_test_db begin
    @testset verbose = true "parameter routes" begin
        @testset verbose = true "create parameter" begin
            project_payload = Dict("name" => "Parameter Project") |> JSON.json
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_data = JSON.parse(project_response.body |> String, Dict{String,Any})
            project_id = project_data["project_id"]

            experiment_payload = Dict(
                "status_id" => (TrackingAPI.IN_PROGRESS |> Integer),
                "name" => "Experiment for Parameters",
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

            iteration_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )
            iteration_data = JSON.parse(
                iteration_response.body |> String,
                Dict{String,Any},
            )
            iteration_id = iteration_data["iteration_id"]

            payload = Dict("key" => "learning_rate", "value" => "0.01") |> JSON.json
            response = HTTP.post(
                "http://127.0.0.1:9000/parameter/iteration/$(iteration_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["parameter_id"] == 1
        end

        @testset verbose = true "get parameter by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/parameter/1";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            parameter = data |> TrackingAPI.Parameter

            @test parameter.id isa Int
            @test parameter.iteration_id == 1
            @test parameter.key == "learning_rate"
            @test parameter.value == "0.01"
        end

        @testset verbose = true "get parameters" begin
            payload = Dict("key" => "batch_size", "value" => "32") |> JSON.json
            HTTP.post(
                "http://127.0.0.1:9000/parameter/iteration/1";
                body=payload,
                status_exception=false,
            )

            response = HTTP.get(
                "http://127.0.0.1:9000/parameter/iteration/1";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Array{Dict{String,Any},1})
            parameters = data .|> TrackingAPI.Parameter

            @test parameters isa Array{TrackingAPI.Parameter,1}
            @test (parameters |> length) == 2
        end

        @testset verbose = true "update parameter" begin
            payload = Dict(
                "key" => "batch_size",
                "value" => "64",
            ) |> JSON.json
            response = HTTP.patch(
                "http://127.0.0.1:9000/parameter/2";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/parameter/2";
                status_exception=false,
            )
            data = JSON.parse(response.body |> String, Dict{String,Any})
            parameter = data |> TrackingAPI.Parameter

            @test parameter.key == "batch_size"
            @test parameter.value == "64"
        end

        @testset verbose = true "delete parameter" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/parameter/2";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "OK"
        end
    end
end
