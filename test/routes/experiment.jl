@with_deardiary_test_db begin
    @testset verbose = true "experiment routes" begin
        @testset verbose = true "create experiment" begin
            project_payload = JSON.json(Dict("name" => "Test Project"))
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_data = JSON.parse(String(project_response.body), Dict{String,Any})
            project_id = project_data["project_id"]

            payload = JSON.json(
                Dict(
                    "status_id" => (Integer(DearDiary.IN_PROGRESS)),
                    "name" => "Test Experiment",
                ),
            )
            response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["experiment_id"] == 1
        end

        @testset verbose = true "get experiment by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/experiment/1"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            experiment = DearDiary.Experiment(data)

            @test experiment.id isa Int
            @test experiment.project_id == 1
            @test experiment.status_id == (Integer(DearDiary.IN_PROGRESS))
            @test experiment.name == "Test Experiment"
            @test isempty(experiment.description)
            @test experiment.created_date isa DateTime
        end

        @testset verbose = true "get experiments" begin
            payload = JSON.json(
                Dict(
                    "status_id" => Integer(DearDiary.IN_PROGRESS),
                    "name" => "Second Experiment",
                ),
            )
            HTTP.post(
                "http://127.0.0.1:9000/experiment/project/1";
                body=payload,
                status_exception=false,
            )

            response = HTTP.get(
                "http://127.0.0.1:9000/experiment/project/1"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["total"] == 2
            @test data["limit"] == 50
            @test data["offset"] == 0
            experiments = DearDiary.Experiment.(data["data"])

            @test experiments isa Array{DearDiary.Experiment,1}
            @test (length(experiments)) == 2

            @testset "limit / offset pagination" begin
                page1 = HTTP.get(
                    "http://127.0.0.1:9000/experiment/project/1?limit=1&offset=0";
                    status_exception=false,
                )
                p1 = JSON.parse(String(page1.body), Dict{String,Any})
                @test (length(p1["data"])) == 1
                @test p1["total"] == 2
                @test p1["limit"] == 1
                @test p1["offset"] == 0

                page2 = HTTP.get(
                    "http://127.0.0.1:9000/experiment/project/1?limit=1&offset=1";
                    status_exception=false,
                )
                p2 = JSON.parse(String(page2.body), Dict{String,Any})
                @test (length(p2["data"])) == 1
                @test p2["offset"] == 1
                @test p1["data"][1]["id"] != p2["data"][1]["id"]

                empty_page = HTTP.get(
                    "http://127.0.0.1:9000/experiment/project/1?limit=10&offset=99";
                    status_exception=false,
                )
                ep = JSON.parse(String(empty_page.body), Dict{String,Any})
                @test isempty(ep["data"])
                @test ep["total"] == 2
            end

            @testset "max_limit cap" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/experiment/project/1?limit=99999";
                    status_exception=false,
                )
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["limit"] == 200
            end

            @testset "invalid limit / offset fall back to defaults" begin
                response = HTTP.get(
                    "http://127.0.0.1:9000/experiment/project/1?limit=abc&offset=-5";
                    status_exception=false,
                )
                data = JSON.parse(String(response.body), Dict{String,Any})
                @test data["limit"] == 50
                @test data["offset"] == 0
            end
        end

        @testset verbose = true "update experiment" begin
            payload = JSON.json(
                Dict(
                    "status_id" => Integer(DearDiary.STOPPED),
                    "name" => nothing,
                    "description" => "Updated experiment",
                    "end_date" => nothing,
                ),
            )
            response = HTTP.patch(
                "http://127.0.0.1:9000/experiment/2"; body=payload, status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/experiment/2"; status_exception=false
            )
            data = JSON.parse(String(response.body), Dict{String,Any})
            experiment = DearDiary.Experiment(data)

            @test experiment.status_id == (Integer(DearDiary.STOPPED))
            @test experiment.name == "Second Experiment"
            @test experiment.description == "Updated experiment"
        end

        @testset verbose = true "delete experiment" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/experiment/2"; status_exception=false
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "OK"
        end

        @testset verbose = true "error envelope on upsert failure" begin
            response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/9999";
                body=(JSON.json(
                    Dict(
                        "status_id" => (Integer(DearDiary.IN_PROGRESS)),
                        "name" => "Orphan Experiment",
                    ),
                )),
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.UNPROCESSABLE_ENTITY
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["code"] == "INVALID_PAYLOAD"
            @test !isempty(data["message"])
        end

        @testset verbose = true "GET 404 carries NOT_FOUND code" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/experiment/9999"; status_exception=false
            )
            @test response.status == HTTP.StatusCodes.NOT_FOUND
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["code"] == "NOT_FOUND"
        end
    end
end
