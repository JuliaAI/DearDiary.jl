@with_deardiary_test_db begin
    @testset verbose = true "parameter routes" begin
        iteration_id = ""
        parameter_id = ""
        second_parameter_id = ""

        @testset verbose = true "create parameter" begin
            project_payload = JSON.json(Dict("name" => "Parameter Project"))
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_data = JSON.parse(String(project_response.body), Dict{String,Any})
            project_id = project_data["project_id"]

            experiment_payload = JSON.json(
                Dict(
                    "status_id" => (Integer(DearDiary.IN_PROGRESS)),
                    "name" => "Experiment for Parameters",
                ),
            )
            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=experiment_payload,
                status_exception=false,
            )
            experiment_data = JSON.parse(String(experiment_response.body), Dict{String,Any})
            experiment_id = experiment_data["experiment_id"]

            iteration_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )
            iteration_data = JSON.parse(String(iteration_response.body), Dict{String,Any})
            iteration_id = iteration_data["iteration_id"]

            payload = JSON.json(Dict("key" => "learning_rate", "value" => "0.01"))
            response = HTTP.post(
                "http://127.0.0.1:9000/parameter/iteration/$(iteration_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            parameter_id = data["parameter_id"]
            @test parameter_id isa String
        end

        @testset verbose = true "get parameter by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/parameter/$(parameter_id)"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            parameter = DearDiary.Parameter(data)

            @test parameter.id isa String
            @test parameter.iteration_id == iteration_id
            @test parameter.key == "learning_rate"
            @test parameter.value == "0.01"
        end

        @testset verbose = true "get parameters" begin
            payload = JSON.json(Dict("key" => "batch_size", "value" => "32"))
            r = HTTP.post(
                "http://127.0.0.1:9000/parameter/iteration/$(iteration_id)";
                body=payload,
                status_exception=false,
            )
            second_parameter_id = JSON.parse(String(r.body), Dict{String,Any})["parameter_id"]

            response = HTTP.get(
                "http://127.0.0.1:9000/parameter/iteration/$(iteration_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["total"] == 2
            @test data["limit"] == 50
            @test data["offset"] == 0
            parameters = DearDiary.Parameter.(data["data"])

            @test parameters isa Array{DearDiary.Parameter,1}
            @test (length(parameters)) == 2
        end

        @testset verbose = true "update parameter" begin
            payload = JSON.json(Dict("key" => "batch_size", "value" => "64"))
            response = HTTP.patch(
                "http://127.0.0.1:9000/parameter/$(second_parameter_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/parameter/$(second_parameter_id)";
                status_exception=false,
            )
            data = JSON.parse(String(response.body), Dict{String,Any})
            parameter = DearDiary.Parameter(data)

            @test parameter.key == "batch_size"
            @test parameter.value == "64"
        end

        @testset verbose = true "delete parameter" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/parameter/$(second_parameter_id)";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "OK"
        end
    end
end
