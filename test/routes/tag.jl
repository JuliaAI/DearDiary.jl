@with_deardiary_test_db begin
    @testset verbose = true "tag routes" begin
        user = DearDiary.get_user("default")
        project_id, _ = DearDiary.create_project(user.id, "Tagged Project")
        experiment_id, _ = DearDiary.create_experiment(
            project_id, DearDiary.IN_PROGRESS, "Tagged Experiment"
        )
        iteration_id, _ = DearDiary.create_iteration(experiment_id)

        @testset "attach tag to project" begin
            payload = JSON.json(Dict("value" => "alpha"))
            response = HTTP.post(
                "http://127.0.0.1:9000/tag/project/$(project_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["association_id"] isa Int
        end

        @testset "attach tag to experiment" begin
            payload = JSON.json(Dict("value" => "beta"))
            response = HTTP.post(
                "http://127.0.0.1:9000/tag/experiment/$(experiment_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
        end

        @testset "attach tag to iteration" begin
            payload = JSON.json(Dict("value" => "gamma"))
            response = HTTP.post(
                "http://127.0.0.1:9000/tag/iteration/$(iteration_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
        end

        @testset "list tags by project" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/tag/project/$(project_id)"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Array{Dict{String,Any},1})
            @test (length(data)) == 1
            @test data[1]["value"] == "alpha"
        end

        @testset "list tags by experiment" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/tag/experiment/$(experiment_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Array{Dict{String,Any},1})
            @test (length(data)) == 1
            @test data[1]["value"] == "beta"
        end

        @testset "list tags by iteration" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/tag/iteration/$(iteration_id)";
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Array{Dict{String,Any},1})
            @test (length(data)) == 1
            @test data[1]["value"] == "gamma"
        end

        @testset "get tag by id" begin
            tag = DearDiary.get_tag("alpha")
            response = HTTP.get(
                "http://127.0.0.1:9000/tag/$(tag.id)"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["value"] == "alpha"
        end

        @testset "delete unattached tag" begin
            unattached, _ = DearDiary.create_tag("orphan")
            response = HTTP.delete(
                "http://127.0.0.1:9000/tag/$(unattached)"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            @test isnothing(DearDiary.get_tag("orphan"))
        end

        @testset "delete attached tag is rejected" begin
            tag = DearDiary.get_tag("gamma")
            response = HTTP.delete(
                "http://127.0.0.1:9000/tag/$(tag.id)"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.INTERNAL_SERVER_ERROR
        end
    end
end
