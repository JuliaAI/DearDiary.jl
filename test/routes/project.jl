@with_deardiary_test_db begin
    @testset verbose = true "project routes" begin
        project_id = ""
        second_project_id = ""

        @testset verbose = true "create project" begin
            payload = JSON.json(Dict("name" => "Missy project"))
            response = HTTP.post(
                "http://127.0.0.1:9000/project"; body=payload, status_exception=false
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            project_id = data["project_id"]
            @test project_id isa String
        end

        @testset verbose = true "get project by id" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/project/$(project_id)"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            project = DearDiary.Project(data)

            @test project.id isa String
            @test project.name == "Missy project"
            @test isempty(project.description)
            @test project.created_date isa DateTime
        end

        @testset verbose = true "get projects" begin
            payload = JSON.json(Dict("name" => "Gala project"))
            r = HTTP.post(
                "http://127.0.0.1:9000/project"; body=payload, status_exception=false
            )
            second_project_id = JSON.parse(String(r.body), Dict{String,Any})["project_id"]

            response = HTTP.get("http://127.0.0.1:9000/project/"; status_exception=false)

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Array{Dict{String,Any},1})
            projects = DearDiary.Project.(data)

            @test projects isa Array{DearDiary.Project,1}
            @test (length(projects)) == 2
        end

        @testset verbose = true "update project" begin
            payload = JSON.json(Dict("name" => nothing, "description" => "Updated project"))
            response = HTTP.patch(
                "http://127.0.0.1:9000/project/$(second_project_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/project/$(second_project_id)"; status_exception=false
            )
            data = JSON.parse(String(response.body), Dict{String,Any})
            project = DearDiary.Project(data)

            @test project.name == "Gala project"
            @test project.description == "Updated project"
        end

        @testset verbose = true "delete project" begin
            response = HTTP.delete(
                "http://127.0.0.1:9000/project/$(second_project_id)"; status_exception=false
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "OK"
        end
    end
end
