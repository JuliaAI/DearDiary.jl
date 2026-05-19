@with_deardiary_test_db begin
    @testset verbose = true "model routes" begin
        @testset verbose = true "create model" begin
            project_payload = Dict("name" => "Model Routes Project") |> JSON.json
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_data = JSON.parse(project_response.body |> String, Dict{String,Any})
            project_id = project_data["project_id"]

            payload = Dict(
                "name" => "fraud-classifier",
                "description" => nothing,
            ) |> JSON.json
            response = HTTP.post(
                "http://127.0.0.1:9000/model/project/$(project_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["model_id"] == 1
        end

        @testset verbose = true "get model by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/model/1"; status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            model = data |> DearDiary.Model

            @test model.id == 1
            @test model.project_id == 1
            @test model.name == "fraud-classifier"
            @test model.created_date isa DateTime
        end

        @testset verbose = true "get models paginated" begin
            HTTP.post(
                "http://127.0.0.1:9000/model/project/1";
                body=(
                    Dict(
                        "name" => "second-model",
                        "description" => nothing,
                    ) |> JSON.json
                ),
                status_exception=false,
            )

            response = HTTP.get(
                "http://127.0.0.1:9000/model/project/1?limit=1&offset=0";
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["total"] == 2
            @test (data["data"] |> length) == 1
        end

        @testset verbose = true "update model" begin
            payload = Dict(
                "name" => nothing,
                "description" => "Updated registry description",
            ) |> JSON.json
            response = HTTP.patch(
                "http://127.0.0.1:9000/model/1";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/model/1"; status_exception=false,
            )
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["description"] == "Updated registry description"
        end

        @testset verbose = true "delete model" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/model/2"; status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["message"] == "OK"
        end

        @testset verbose = true "GET 404 carries NOT_FOUND code" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/model/9999"; status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.NOT_FOUND
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["code"] == "NOT_FOUND"
        end

        @testset verbose = true "duplicate name surfaces CONFLICT" begin
            response = HTTP.post(
                "http://127.0.0.1:9000/model/project/1";
                body=(
                    Dict(
                        "name" => "fraud-classifier",
                        "description" => nothing,
                    ) |> JSON.json
                ),
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.CONFLICT
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["code"] == "CONFLICT"
        end
    end
end
