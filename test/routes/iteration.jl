@with_deardiary_test_db begin
    @testset verbose = true "iteration routes" begin
        experiment_id = ""
        iteration_id = ""
        second_iteration_id = ""

        @testset verbose = true "create iteration" begin
            project_payload = JSON.json(Dict("name" => "Iteration Project"))
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
                    "name" => "Experiment for Iterations",
                ),
            )
            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=experiment_payload,
                status_exception=false,
            )
            experiment_data = JSON.parse(String(experiment_response.body), Dict{String,Any})
            experiment_id = experiment_data["experiment_id"]

            response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            iteration_id = data["iteration_id"]
            @test iteration_id isa String
        end

        @testset verbose = true "get iteration by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/iteration/$(iteration_id)"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            iteration = DearDiary.Iteration(data)

            @test iteration.id isa String
            @test iteration.experiment_id == experiment_id
            @test isempty(iteration.notes)
            @test iteration.created_date isa DateTime
        end

        @testset verbose = true "get iterations" begin
            r = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )
            second_iteration_id = JSON.parse(String(r.body), Dict{String,Any})["iteration_id"]

            response = HTTP.get(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["total"] == 2
            @test data["limit"] == 50
            @test data["offset"] == 0
            iterations = DearDiary.Iteration.(data["data"])

            @test iterations isa Array{DearDiary.Iteration,1}
            @test (length(iterations)) == 2
        end

        @testset verbose = true "update iteration" begin
            payload = JSON.json(
                Dict("notes" => "Updated notes for iteration", "end_date" => nothing)
            )
            response = HTTP.patch(
                "http://127.0.0.1:9000/iteration/$(second_iteration_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/iteration/$(second_iteration_id)";
                status_exception=false,
            )
            data = JSON.parse(String(response.body), Dict{String,Any})
            iteration = DearDiary.Iteration(data)

            @test iteration.notes == "Updated notes for iteration"
        end

        @testset verbose = true "delete iteration" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/iteration/$(second_iteration_id)";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "OK"
        end

        @testset verbose = true "create child iteration via ?parent_iteration_id=" begin
            # Build a fresh experiment to avoid colliding with iterations created above.
            project_payload = JSON.json(Dict("name" => "Iteration Lineage Project"))
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_data = JSON.parse(String(project_response.body), Dict{String,Any})
            project_id = project_data["project_id"]

            experiment_payload = JSON.json(
                Dict("status_id" => (Integer(DearDiary.IN_PROGRESS)), "name" => "Sweep")
            )
            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=experiment_payload,
                status_exception=false,
            )
            experiment_id = JSON.parse(String(experiment_response.body), Dict{String,Any})["experiment_id"]

            parent_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )
            parent_id = JSON.parse(String(parent_response.body), Dict{String,Any})["iteration_id"]

            child_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)?parent_iteration_id=$(parent_id)";
                status_exception=false,
            )
            @test child_response.status == HTTP.StatusCodes.CREATED
            child_id = JSON.parse(String(child_response.body), Dict{String,Any})["iteration_id"]

            @testset "GET /iteration/{parent_id}/children" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/iteration/$(parent_id)/children";
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(String(response.body))
                @test (length(data)) == 1
                child = DearDiary.Iteration(data[1])
                @test child.id == child_id
                @test child.parent_iteration_id == parent_id
            end

            @testset "non-integer parent_iteration_id is rejected" begin
                response = HTTP.post(
                    "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)?parent_iteration_id=notanint";
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.UNPROCESSABLE_ENTITY
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["code"] == "INVALID_PAYLOAD"
            end
        end

        @testset verbose = true "PATCH status_id and error_message" begin
            project_payload = JSON.json(Dict("name" => "Iteration Status Project"))
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_id = JSON.parse(String(project_response.body), Dict{String,Any})["project_id"]

            experiment_payload = JSON.json(
                Dict(
                    "status_id" => (Integer(DearDiary.IN_PROGRESS)),
                    "name" => "Status Sweep",
                ),
            )
            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=experiment_payload,
                status_exception=false,
            )
            experiment_id = JSON.parse(String(experiment_response.body), Dict{String,Any})["experiment_id"]

            iteration_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )
            iteration_id = JSON.parse(String(iteration_response.body), Dict{String,Any})["iteration_id"]

            payload = JSON.json(
                Dict(
                    "notes" => nothing,
                    "end_date" => string(Dates.now()),
                    "status_id" => (Integer(DearDiary.FAILED)),
                    "error_message" => "OutOfMemoryError",
                ),
            )
            patch_response = HTTP.patch(
                "http://127.0.0.1:9000/iteration/$(iteration_id)";
                body=payload,
                status_exception=false,
            )
            @test patch_response.status == HTTP.StatusCodes.OK

            getter = HTTP.get(
                "http://127.0.0.1:9000/iteration/$(iteration_id)"; status_exception=false
            )
            stored = DearDiary.Iteration(JSON.parse(String(getter.body), Dict{String,Any}))
            @test stored.status_id == (Integer(DearDiary.FAILED))
            @test stored.error_message == "OutOfMemoryError"
        end
    end
end
