@with_deardiary_test_db begin
    @testset verbose = true "model version routes" begin
        # Scaffold: project -> experiment -> iteration -> model
        project_payload = Dict("name" => "MV Routes Project") |> JSON.json
        project_response = HTTP.post(
            "http://127.0.0.1:9000/project";
            body=project_payload,
            status_exception=false,
        )
        project_id = JSON.parse(
            project_response.body |> String, Dict{String,Any},
        )["project_id"]

        experiment_payload = Dict(
            "status_id" => (DearDiary.IN_PROGRESS |> Integer),
            "name" => "MV Routes Experiment",
        ) |> JSON.json
        experiment_response = HTTP.post(
            "http://127.0.0.1:9000/experiment/project/$(project_id)";
            body=experiment_payload,
            status_exception=false,
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

        model_response = HTTP.post(
            "http://127.0.0.1:9000/model/project/$(project_id)";
            body=(
                Dict(
                    "name" => "routes-model",
                    "description" => nothing,
                ) |> JSON.json
            ),
            status_exception=false,
        )
        model_id = JSON.parse(
            model_response.body |> String, Dict{String,Any},
        )["model_id"]

        @testset verbose = true "create model version" begin
            payload = Dict(
                "iteration_id" => iteration_id,
                "resource_id" => nothing,
                "description" => nothing,
            ) |> JSON.json
            response = HTTP.post(
                "http://127.0.0.1:9000/modelversion/model/$(model_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["modelversion_id"] isa Integer

            version_id = data["modelversion_id"]
            response = HTTP.get(
                "http://127.0.0.1:9000/modelversion/$(version_id)";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            version = JSON.parse(
                response.body |> String, Dict{String,Any},
            ) |> DearDiary.ModelVersion
            @test version.model_id == model_id
            @test version.version == 1
            @test version.stage_id == (DearDiary.NO_STAGE |> Integer)
        end

        @testset verbose = true "promotion auto-archives prior PRODUCTION" begin
            # Register two more versions so we have v2 + v3
            for _ in 1:2
                HTTP.post(
                    "http://127.0.0.1:9000/modelversion/model/$(model_id)";
                    body=(
                        Dict(
                            "iteration_id" => iteration_id,
                            "resource_id" => nothing,
                            "description" => nothing,
                        ) |> JSON.json
                    ),
                    status_exception=false,
                )
            end

            list_response = HTTP.get(
                "http://127.0.0.1:9000/modelversion/model/$(model_id)";
                status_exception=false,
            )
            list = JSON.parse(list_response.body |> String, Dict{String,Any})
            versions = list["data"] .|> DearDiary.ModelVersion
            @test (versions |> length) == 3

            v2_id = versions[2].id
            v3_id = versions[3].id

            # Promote v2 to PRODUCTION.
            HTTP.patch(
                "http://127.0.0.1:9000/modelversion/$(v2_id)";
                body=(
                    Dict(
                        "stage_id" => (DearDiary.PRODUCTION |> Integer),
                        "description" => nothing,
                        "resource_id" => nothing,
                    ) |> JSON.json
                ),
                status_exception=false,
            )

            # Promote v3 to PRODUCTION — v2 must auto-archive.
            response = HTTP.patch(
                "http://127.0.0.1:9000/modelversion/$(v3_id)";
                body=(
                    Dict(
                        "stage_id" => (DearDiary.PRODUCTION |> Integer),
                        "description" => nothing,
                        "resource_id" => nothing,
                    ) |> JSON.json
                ),
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK

            v2_after = JSON.parse(
                HTTP.get(
                    "http://127.0.0.1:9000/modelversion/$(v2_id)";
                    status_exception=false,
                ).body |> String, Dict{String,Any},
            ) |> DearDiary.ModelVersion
            v3_after = JSON.parse(
                HTTP.get(
                    "http://127.0.0.1:9000/modelversion/$(v3_id)";
                    status_exception=false,
                ).body |> String, Dict{String,Any},
            ) |> DearDiary.ModelVersion

            @test v2_after.stage_id == (DearDiary.ARCHIVED |> Integer)
            @test v3_after.stage_id == (DearDiary.PRODUCTION |> Integer)
        end

        @testset verbose = true "GET 404 carries NOT_FOUND code" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/modelversion/9999"; status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.NOT_FOUND
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["code"] == "NOT_FOUND"
        end
    end
end
