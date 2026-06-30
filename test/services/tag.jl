@with_deardiary_test_db begin
    @testset verbose = true "Tag service" begin
        @testset verbose = true "get_tag by id" begin
            result = DearDiary.insert(DearDiary.Tag, "test-tag-service")
            tag_id = result.id

            tag = DearDiary.get_tag(tag_id)
            @test tag isa DearDiary.Tag
            @test tag.id == tag_id
            @test tag.value == "test-tag-service"
        end

        @testset verbose = true "get_tag by value" begin
            tag = DearDiary.get_tag_by_value("test-tag-service")
            @test tag isa DearDiary.Tag
            @test tag.value == "test-tag-service"
        end

        @testset verbose = true "get_tag with non-existent id" begin
            tag = DearDiary.get_tag("00000000-0000-0000-0000-000000000000")
            @test isnothing(tag)
        end

        @testset verbose = true "get_tags by project" begin
            project_result = DearDiary.insert(DearDiary.Project, "test-project-tags")
            project_id = project_result.id

            DearDiary.insert_tag(DearDiary.Project, project_id, "project-tag-1")
            DearDiary.insert_tag(DearDiary.Project, project_id, "project-tag-2")

            tags = DearDiary.get_tags(DearDiary.Project, project_id)
            @test (length(tags)) == 2
            @test tags[1].value == "project-tag-1"
            @test tags[2].value == "project-tag-2"
        end

        @testset verbose = true "get_tags by experiment" begin
            project_result = DearDiary.insert(DearDiary.Project, "test-project-exp")
            experiment_result = DearDiary.insert(
                DearDiary.Experiment,
                project_result.id,
                Int(DearDiary.IN_PROGRESS),
                "test-experiment-tags",
            )
            experiment_id = experiment_result.id

            DearDiary.insert_tag(DearDiary.Experiment, experiment_id, "exp-tag-1")
            DearDiary.insert_tag(DearDiary.Experiment, experiment_id, "exp-tag-2")

            tags = DearDiary.get_tags(DearDiary.Experiment, experiment_id)
            @test (length(tags)) == 2
            @test tags[1].value == "exp-tag-1"
            @test tags[2].value == "exp-tag-2"
        end

        @testset verbose = true "get_tags by iteration" begin
            project_result = DearDiary.insert(DearDiary.Project, "test-project-iter")
            experiment_result = DearDiary.insert(
                DearDiary.Experiment,
                project_result.id,
                Int(DearDiary.IN_PROGRESS),
                "test-experiment-iter",
            )
            iteration_result = DearDiary.insert(DearDiary.Iteration, experiment_result.id)
            iteration_id = iteration_result.id

            DearDiary.insert_tag(DearDiary.Iteration, iteration_id, "iter-tag-1")
            DearDiary.insert_tag(DearDiary.Iteration, iteration_id, "iter-tag-2")

            tags = DearDiary.get_tags(DearDiary.Iteration, iteration_id)
            @test (length(tags)) == 2
            @test tags[1].value == "iter-tag-1"
            @test tags[2].value == "iter-tag-2"
        end

        @testset verbose = true "create_tag" begin
            result = DearDiary.create_tag("new-tag-service")
            @test result.id isa String
            @test !isempty(result.id)
            @test result.status === DearDiary.Created

            tag = DearDiary.get_tag(result.id)
            @test tag isa DearDiary.Tag
            @test tag.value == "new-tag-service"
        end

        @testset verbose = true "create_tag duplicate" begin
            result = DearDiary.create_tag("new-tag-service")
            @test isnothing(result.id)
            @test result.status === DearDiary.Duplicate
        end

        @testset verbose = true "add_tag to project" begin
            project_result = DearDiary.insert(DearDiary.Project, "test-project-add")
            project_id = project_result.id

            result = DearDiary.add_tag(DearDiary.Project, project_id, "added-project-tag")
            @test result.id isa String
            @test !isempty(result.id)
            @test result.status === DearDiary.Created

            tags = DearDiary.get_tags(DearDiary.Project, project_id)
            @test (length(tags)) >= 1
            tag_values = [tag.value for tag in tags]
            @test "added-project-tag" in tag_values
        end

        @testset verbose = true "add_tag to project with non-existent project" begin
            result = DearDiary.add_tag(
                DearDiary.Project, "00000000-0000-0000-0000-000000000000", "some-tag"
            )
            @test isnothing(result.id)
            @test result.status === DearDiary.Unprocessable
        end

        @testset verbose = true "add_tag to experiment" begin
            project_result = DearDiary.insert(DearDiary.Project, "test-project-exp-add")
            experiment_result = DearDiary.insert(
                DearDiary.Experiment,
                project_result.id,
                Int(DearDiary.IN_PROGRESS),
                "test-exp-add",
            )
            experiment_id = experiment_result.id

            result = DearDiary.add_tag(DearDiary.Experiment, experiment_id, "added-exp-tag")
            @test result.id isa String
            @test !isempty(result.id)
            @test result.status === DearDiary.Created

            tags = DearDiary.get_tags(DearDiary.Experiment, experiment_id)
            @test (length(tags)) >= 1
            tag_values = [tag.value for tag in tags]
            @test "added-exp-tag" in tag_values
        end

        @testset verbose = true "add_tag to experiment with non-existent experiment" begin
            result = DearDiary.add_tag(
                DearDiary.Experiment, "00000000-0000-0000-0000-000000000000", "some-tag"
            )
            @test isnothing(result.id)
            @test result.status === DearDiary.Unprocessable
        end

        @testset verbose = true "add_tag to iteration" begin
            project_result = DearDiary.insert(DearDiary.Project, "test-project-iter-add")
            experiment_result = DearDiary.insert(
                DearDiary.Experiment,
                project_result.id,
                Int(DearDiary.IN_PROGRESS),
                "test-exp-iter-add",
            )
            iteration_result = DearDiary.insert(DearDiary.Iteration, experiment_result.id)
            iteration_id = iteration_result.id

            result = DearDiary.add_tag(DearDiary.Iteration, iteration_id, "added-iter-tag")
            @test result.id isa String
            @test !isempty(result.id)
            @test result.status === DearDiary.Created

            tags = DearDiary.get_tags(DearDiary.Iteration, iteration_id)
            @test (length(tags)) >= 1
            tag_values = [tag.value for tag in tags]
            @test "added-iter-tag" in tag_values
        end

        @testset verbose = true "add_tag to iteration with non-existent iteration" begin
            result = DearDiary.add_tag(
                DearDiary.Iteration, "00000000-0000-0000-0000-000000000000", "some-tag"
            )
            @test isnothing(result.id)
            @test result.status === DearDiary.Unprocessable
        end

        @testset verbose = true "delete_tag" begin
            result = DearDiary.create_tag("tag-to-delete")
            tag_id = result.id

            deleted = DearDiary.delete_tag(tag_id)
            @test deleted == true

            tag = DearDiary.get_tag(tag_id)
            @test isnothing(tag)
        end

        @testset verbose = true "delete_tag non-existent" begin
            deleted = DearDiary.delete_tag("00000000-0000-0000-0000-000000000000")
            @test deleted == true
        end
    end
end
