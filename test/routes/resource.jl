@with_tracking_test_db begin
    @testset verbose = true "resource routes" begin
        dummy_file = "dummy.bin"
        try
            write(dummy_file, rand(UInt8, 1024))

            @testset verbose = true "create resource" begin
                project_payload = Dict("name" => "Resource Project") |> JSON.json
                project_response = HTTP.post(
                    "http://127.0.0.1:9000/project";
                    body=project_payload,
                    status_exception=false,
                )
                project_data = JSON.parse(project_response.body |> String, Dict{String,Any})
                project_id = project_data["project_id"]

                experiment_payload = Dict(
                    "status_id" => (Tracking.IN_PROGRESS |> Integer),
                    "name" => "Experiment for Resources",
                ) |> JSON.json
                experiment_response = HTTP.post(
                    "http://127.0.0.1:9000/experiment/project/$(project_id)";
                    body=experiment_payload,
                    status_exception=false,
                )
                experiment_data = JSON.parse(experiment_response.body |> String, Dict{String,Any})
                experiment_id = experiment_data["experiment_id"]

                form = HTTP.Form(Dict(
                    "name" => "model_weights",
                    "data" => HTTP.Multipart("dummy.bin", open(dummy_file))
                ))

                response = HTTP.post(
                    "http://127.0.0.1:9000/resource/experiment/$(experiment_id)";
                    body=form,
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.CREATED
                data = JSON.parse(response.body |> String, Dict{String,Any})
                @test data["resource_id"] == 1
            end

            @testset verbose = true "get resource by id" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/resource/1";
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(response.body |> String, Dict{String,Any})
                resource = data |> Tracking.Resource
                @test resource.id isa Int
                @test resource.experiment_id == 1
                @test resource.name == "model_weights"
                @test length(resource.data) == 1024
            end

            @testset verbose = true "get resources" begin
                form = HTTP.Form(Dict(
                    "name" => "config_file",
                    "data" => HTTP.Multipart("dummy.bin", open(dummy_file))
                ))

                HTTP.post(
                    "http://127.0.0.1:9000/resource/experiment/1";
                    body=form,
                    status_exception=false,
                )

                response = HTTP.get(
                    "http://127.0.0.1:9000/resource/experiment/1";
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(response.body |> String, Array{Dict{String,Any},1})
                resources = data .|> Tracking.Resource
                @test resources isa Array{Tracking.Resource,1}
                @test length(resources) == 2
            end

            @testset verbose = true "update resource" begin
                form = HTTP.Form(Dict(
                    "name" => "model_weights_v2",
                    "description" => "Updated model weights",
                    "data" => HTTP.Multipart("dummy.bin", open(dummy_file))
                ))

                response = HTTP.patch(
                    "http://127.0.0.1:9000/resource/2";
                    body=form,
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(response.body |> String, Dict{String,Any})
                @test data["message"] == "UPDATED"

                response = HTTP.get(
                    "http://127.0.0.1:9000/resource/2";
                    status_exception=false,
                )
                data = JSON.parse(response.body |> String, Dict{String,Any})
                resource = data |> Tracking.Resource
                @test resource.name == "model_weights_v2"
                @test resource.description == "Updated model weights"
                @test length(resource.data) == 1024
            end

            @testset verbose = true "delete resource" begin
                response = HTTP.delete(
                    "http://127.0.0.1:9000/resource/2";
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.OK
                data = JSON.parse(response.body |> String, Dict{String,Any})
                @test data["message"] == "OK"
            end
        finally
            isfile(dummy_file) && rm(dummy_file)
        end
    end
end
