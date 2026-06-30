@with_deardiary_test_db begin
    @testset verbose = true "project repository" begin
        @testset verbose = true "insert" begin
            id, status = DearDiary.insert(DearDiary.Project, "Project Missy")
            @test id isa String
            @test !isempty(id)
            @test status === DearDiary.Created
        end

        @testset verbose = true "fetch" begin
            project_id, _ = DearDiary.insert(DearDiary.Project, "Project Missy Fetch")
            project = DearDiary.fetch(DearDiary.Project, project_id)

            @test project isa DearDiary.Project
            @test project.id == project_id
            @test project.name == "Project Missy Fetch"
            @test isempty(project.description)
            @test project.created_date isa DateTime
        end

        @testset verbose = true "fetch all" begin
            DearDiary.insert(DearDiary.Project, "Project Gala")

            projects = DearDiary.fetch_all(DearDiary.Project)

            @test projects isa Array{DearDiary.Project,1}
            @test (length(projects)) >= 2
        end

        @testset verbose = true "update" begin
            project_id, _ = DearDiary.insert(DearDiary.Project, "Project Choclo Orig")
            @test DearDiary.update(
                DearDiary.Project,
                project_id;
                name="Project Choclo",
                description="Updated project",
            ) === DearDiary.Updated

            project = DearDiary.fetch(DearDiary.Project, project_id)

            @test project.name == "Project Choclo"
            @test project.description == "Updated project"
        end

        @testset verbose = true "delete" begin
            project_id, _ = DearDiary.insert(DearDiary.Project, "Project Delete Me")
            @test DearDiary.delete(DearDiary.Project, project_id)
            @test isnothing(DearDiary.fetch(DearDiary.Project, project_id))
        end
    end
end
