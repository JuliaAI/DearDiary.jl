@with_deardiary_test_db begin
    @testset verbose = true "project repository" begin
        @testset verbose = true "insert" begin
            id, status = DearDiary.insert(
                DearDiary.Project,
                "Project Missy",
            )
            @test id isa Integer
            @test status isa DearDiary.Created
        end

        @testset verbose = true "fetch" begin
            project = DearDiary.fetch(DearDiary.Project, 1)

            @test project isa DearDiary.Project
            @test project.id == 1
            @test project.name == "Project Missy"
            @test project.description |> isempty
            @test project.created_date isa DateTime
        end

        @testset verbose = true "fetch all" begin
            DearDiary.insert(DearDiary.Project, "Project Gala")

            projects = DearDiary.Project |> DearDiary.fetch_all

            @test projects isa Array{DearDiary.Project,1}
            @test (projects |> length) == 2
        end

        @testset verbose = true "update" begin
            @test DearDiary.update(
                DearDiary.Project, 1;
                name="Project Choclo",
                description="Updated project"
            ) isa DearDiary.Updated

            project = DearDiary.fetch(DearDiary.Project, 1)

            @test project.name == "Project Choclo"
            @test project.description == "Updated project"
        end

        @testset verbose = true "delete" begin
            @test DearDiary.delete(DearDiary.Project, 1)
            @test DearDiary.fetch(DearDiary.Project, 1) |> isnothing
        end
    end
end
