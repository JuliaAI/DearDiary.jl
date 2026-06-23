@with_deardiary_test_db begin
    @testset verbose = true "project repository" begin
        @testset verbose = true "insert" begin
            id, status = DearDiary.insert(DearDiary.Project, "Project Missy")
            @test id isa Integer
            @test status === DearDiary.Created
        end

        @testset verbose = true "fetch" begin
            project = DearDiary.fetch(DearDiary.Project, 1)

            @test project isa DearDiary.Project
            @test project.id == 1
            @test project.name == "Project Missy"
            @test isempty(project.description)
            @test project.created_date isa DateTime
        end

        @testset verbose = true "fetch all" begin
            DearDiary.insert(DearDiary.Project, "Project Gala")

            projects = DearDiary.fetch_all(DearDiary.Project)

            @test projects isa Array{DearDiary.Project,1}
            @test (length(projects)) == 2
        end

        @testset verbose = true "update" begin
            @test DearDiary.update(
                DearDiary.Project, 1; name="Project Choclo", description="Updated project"
            ) === DearDiary.Updated

            project = DearDiary.fetch(DearDiary.Project, 1)

            @test project.name == "Project Choclo"
            @test project.description == "Updated project"
        end

        @testset verbose = true "delete" begin
            @test DearDiary.delete(DearDiary.Project, 1)
            @test isnothing(DearDiary.fetch(DearDiary.Project, 1))
        end
    end
end
