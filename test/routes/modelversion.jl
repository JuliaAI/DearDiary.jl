@with_deardiary_test_db begin
    @testset verbose = true "model version routes" begin
        # Scaffold: project -> experiment -> iteration -> model
        project_payload = JSON.json(Dict("name" => "MV Routes Project"))
        project_response = HTTP.post(
            "http://127.0.0.1:9000/project"; body=project_payload, status_exception=false
        )
        project_id = JSON.parse(String(project_response.body), Dict{String,Any})["project_id"]

        experiment_payload = JSON.json(
            Dict(
                "status_id" => (Integer(DearDiary.IN_PROGRESS)),
                "name" => "MV Routes Experiment",
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

        model_response = HTTP.post(
            "http://127.0.0.1:9000/model/project/$(project_id)";
            body=(JSON.json(Dict("name" => "routes-model", "description" => nothing))),
            status_exception=false,
        )
        model_id = JSON.parse(String(model_response.body), Dict{String,Any})["model_id"]

        @testset verbose = true "create model version" begin
            payload = JSON.json(
                Dict(
                    "iteration_id" => iteration_id,
                    "resource_id" => nothing,
                    "description" => nothing,
                ),
            )
            response = HTTP.post(
                "http://127.0.0.1:9000/modelversion/model/$(model_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["modelversion_id"] isa String
            @test !isempty(data["modelversion_id"])

            version_id = data["modelversion_id"]
            response = HTTP.get(
                "http://127.0.0.1:9000/modelversion/$(version_id)"; status_exception=false
            )
            @test response.status == HTTP.StatusCodes.OK
            version = DearDiary.ModelVersion(
                JSON.parse(String(response.body), Dict{String,Any})
            )
            @test version.model_id == model_id
            @test version.version == 1
            @test version.stage_id == (Integer(DearDiary.NO_STAGE))
        end

        @testset verbose = true "promotion auto-archives prior PRODUCTION" begin
            # Register two more versions so we have v2 + v3
            for _ in 1:2
                HTTP.post(
                    "http://127.0.0.1:9000/modelversion/model/$(model_id)";
                    body=(JSON.json(
                        Dict(
                            "iteration_id" => iteration_id,
                            "resource_id" => nothing,
                            "description" => nothing,
                        ),
                    )),
                    status_exception=false,
                )
            end

            list_response = HTTP.get(
                "http://127.0.0.1:9000/modelversion/model/$(model_id)";
                status_exception=false,
            )
            list = JSON.parse(String(list_response.body), Dict{String,Any})
            versions = DearDiary.ModelVersion.(list["data"])
            @test (length(versions)) == 3

            v2_id = versions[2].id
            v3_id = versions[3].id

            # Promote v2 to PRODUCTION.
            HTTP.patch(
                "http://127.0.0.1:9000/modelversion/$(v2_id)";
                body=(JSON.json(
                    Dict(
                        "stage_id" => (Integer(DearDiary.PRODUCTION)),
                        "description" => nothing,
                        "resource_id" => nothing,
                    ),
                )),
                status_exception=false,
            )

            # Promote v3 to PRODUCTION; v2 must auto-archive.
            response = HTTP.patch(
                "http://127.0.0.1:9000/modelversion/$(v3_id)";
                body=(JSON.json(
                    Dict(
                        "stage_id" => (Integer(DearDiary.PRODUCTION)),
                        "description" => nothing,
                        "resource_id" => nothing,
                    ),
                )),
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK

            v2_after = DearDiary.ModelVersion(
                JSON.parse(
                    String(
                        HTTP.get(
                            "http://127.0.0.1:9000/modelversion/$(v2_id)";
                            status_exception=false,
                        ).body,
                    ),
                    Dict{String,Any},
                ),
            )
            v3_after = DearDiary.ModelVersion(
                JSON.parse(
                    String(
                        HTTP.get(
                            "http://127.0.0.1:9000/modelversion/$(v3_id)";
                            status_exception=false,
                        ).body,
                    ),
                    Dict{String,Any},
                ),
            )

            @test v2_after.stage_id == (Integer(DearDiary.ARCHIVED))
            @test v3_after.stage_id == (Integer(DearDiary.PRODUCTION))
        end

        @testset verbose = true "GET 404 carries NOT_FOUND code" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/modelversion/00000000-0000-0000-0000-000000000000";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.NOT_FOUND
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["code"] == "NOT_FOUND"
        end
    end
end
