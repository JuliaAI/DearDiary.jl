@with_deardiary_test_db begin
    @testset verbose = true "tag repository" begin
        @testset verbose = true "insert" begin
            result = DearDiary.insert(DearDiary.Tag, "test-tag")
            @test result.id isa String
            @test !isempty(result.id)
            @test result.status === DearDiary.Created
        end

        @testset verbose = true "fetch by id" begin
            inserted = DearDiary.insert(DearDiary.Tag, "test-tag-fetchbyid")
            tag = DearDiary.fetch(DearDiary.Tag, inserted.id)

            @test tag isa DearDiary.Tag
            @test tag.id == inserted.id
            @test tag.value == "test-tag-fetchbyid"
        end

        @testset verbose = true "fetch by value" begin
            tag = DearDiary.fetch_by_value(DearDiary.Tag, "test-tag")

            @test tag isa DearDiary.Tag
            @test tag.id isa String
            @test !isempty(tag.id)
            @test tag.value == "test-tag"
        end

        @testset verbose = true "delete" begin
            inserted = DearDiary.insert(DearDiary.Tag, "test-tag-delete")
            @test DearDiary.delete(DearDiary.Tag, inserted.id)
            @test isnothing(DearDiary.fetch(DearDiary.Tag, inserted.id))
        end
    end

    @testset verbose = true "fetch tags association" begin
        @testset verbose = true "fetch tags by project id" begin
            project_result = DearDiary.insert(DearDiary.Project, "test-project")
            project_id = project_result.id

            tag_result = DearDiary.insert_tag(
                DearDiary.Project, project_id, "test-project-tag"
            )

            tags = DearDiary.fetch_tags(DearDiary.Project, project_id)
            @test length(tags) == 1
            @test tags[1].value == "test-project-tag"
        end

        @testset verbose = true "fetch tags by experiment id" begin
            project_result = DearDiary.insert(DearDiary.Project, "test-project")
            experiment_result = DearDiary.insert(
                DearDiary.Experiment,
                project_result.id,
                Int(DearDiary.IN_PROGRESS),
                "test-experiment",
            )
            experiment_id = experiment_result.id

            tag_result = DearDiary.insert_tag(
                DearDiary.Experiment, experiment_id, "test-experiment-tag"
            )

            tags = DearDiary.fetch_tags(DearDiary.Experiment, experiment_id)
            @test length(tags) == 1
            @test tags[1].value == "test-experiment-tag"
        end

        @testset verbose = true "fetch tags by iteration id" begin
            project_result = DearDiary.insert(DearDiary.Project, "test-project")
            experiment_result = DearDiary.insert(
                DearDiary.Experiment,
                project_result.id,
                Int(DearDiary.IN_PROGRESS),
                "test-experiment",
            )
            iteration_result = DearDiary.insert(DearDiary.Iteration, experiment_result.id)
            iteration_id = iteration_result.id

            tag_result = DearDiary.insert_tag(
                DearDiary.Iteration, iteration_id, "test-iteration-tag"
            )

            tags = DearDiary.fetch_tags(DearDiary.Iteration, iteration_id)
            @test length(tags) == 1
            @test tags[1].value == "test-iteration-tag"
        end
    end

    @testset verbose = true "insert tags association" begin
        project_result = DearDiary.insert(DearDiary.Project, "test-project")
        experiment_result = DearDiary.insert(
            DearDiary.Experiment,
            project_result.id,
            Int(DearDiary.IN_PROGRESS),
            "test-experiment",
        )
        iteration_result = DearDiary.insert(DearDiary.Iteration, experiment_result.id)

        project_tag_result = DearDiary.insert_tag(
            DearDiary.Project, project_result.id, "test-project-tag"
        )
        experiment_tag_result = DearDiary.insert_tag(
            DearDiary.Experiment, experiment_result.id, "test-experiment-tag"
        )
        iteration_tag_result = DearDiary.insert_tag(
            DearDiary.Iteration, iteration_result.id, "test-iteration-tag"
        )

        @test project_tag_result.id isa String
        @test !isempty(project_tag_result.id)
        @test project_tag_result.status === DearDiary.Created
        @test experiment_tag_result.id isa String
        @test !isempty(experiment_tag_result.id)
        @test experiment_tag_result.status === DearDiary.Created
        @test iteration_tag_result.id isa String
        @test !isempty(iteration_tag_result.id)
        @test iteration_tag_result.status === DearDiary.Created
    end
end
