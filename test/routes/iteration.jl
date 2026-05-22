@with_deardiary_test_db begin
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
                "status_id" => (DearDiary.IN_PROGRESS |> Integer),
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
            iteration = data |> DearDiary.Iteration

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
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["total"] == 2
            @test data["limit"] == 50
            @test data["offset"] == 0
            iterations = data["data"] .|> DearDiary.Iteration

            @test iterations isa Array{DearDiary.Iteration,1}
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
            iteration = data |> DearDiary.Iteration

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

        @testset verbose = true "create child iteration via ?parent_iteration_id=" begin
            # Build a fresh experiment to avoid colliding with iterations created above.
            project_payload = Dict("name" => "Iteration Lineage Project") |> JSON.json
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload, status_exception=false,
            )
            project_data = JSON.parse(
                project_response.body |> String, Dict{String,Any},
            )
            project_id = project_data["project_id"]

            experiment_payload = Dict(
                "status_id" => (DearDiary.IN_PROGRESS |> Integer),
                "name" => "Sweep",
            ) |> JSON.json
            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=experiment_payload, status_exception=false,
            )
            experiment_id = JSON.parse(
                experiment_response.body |> String, Dict{String,Any},
            )["experiment_id"]

            parent_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )
            parent_id = JSON.parse(
                parent_response.body |> String, Dict{String,Any},
            )["iteration_id"]

            child_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)?parent_iteration_id=$(parent_id)";
                status_exception=false,
            )
            @test child_response.status == HTTP.StatusCodes.CREATED
            child_id = JSON.parse(
                child_response.body |> String, Dict{String,Any},
            )["iteration_id"]

            @testset "GET /iteration/{parent_id}/children" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/iteration/$(parent_id)/children";
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(response.body |> String)
                @test (data |> length) == 1
                child = data[1] |> DearDiary.Iteration
                @test child.id == child_id
                @test child.parent_iteration_id == parent_id
            end

            @testset "non-integer parent_iteration_id is rejected" begin
                response = HTTP.post(
                    "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)?parent_iteration_id=notanint";
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.UNPROCESSABLE_ENTITY
                data = JSON.parse(response.body |> String, Dict{String,Any})
                @test data["code"] == "INVALID_PAYLOAD"
            end
        end

        @testset verbose = true "PATCH status_id and error_message" begin
            project_payload = Dict("name" => "Iteration Status Project") |> JSON.json
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload, status_exception=false,
            )
            project_id = JSON.parse(
                project_response.body |> String, Dict{String,Any},
            )["project_id"]

            experiment_payload = Dict(
                "status_id" => (DearDiary.IN_PROGRESS |> Integer),
                "name" => "Status Sweep",
            ) |> JSON.json
            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=experiment_payload, status_exception=false,
            )
            experiment_id = JSON.parse(
                experiment_response.body |> String, Dict{String,Any},
            )["experiment_id"]

            iteration_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )
            iteration_id = JSON.parse(
                iteration_response.body |> String, Dict{String,Any},
            )["iteration_id"]

            payload = Dict(
                "notes" => nothing,
                "end_date" => Dates.now() |> string,
                "status_id" => (DearDiary.FAILED |> Integer),
                "error_message" => "OutOfMemoryError",
            ) |> JSON.json
            patch_response = HTTP.patch(
                "http://127.0.0.1:9000/iteration/$(iteration_id)";
                body=payload, status_exception=false,
            )
            @test patch_response.status == HTTP.StatusCodes.OK

            getter = HTTP.get(
                "http://127.0.0.1:9000/iteration/$(iteration_id)";
                status_exception=false,
            )
            stored = JSON.parse(
                getter.body |> String, Dict{String,Any},
            ) |> DearDiary.Iteration
            @test stored.status_id == (DearDiary.FAILED |> Integer)
            @test stored.error_message == "OutOfMemoryError"
        end
    end
end
