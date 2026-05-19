@with_deardiary_test_db begin
    @testset verbose = true "model version repository" begin
        function _scaffold()
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "ModelVersion Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Experiment for Versions",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            model_id, _ = DearDiary.insert(
                DearDiary.Model, project_id, "fraud-classifier",
            )
            return (project_id, experiment_id, iteration_id, model_id)
        end

        @testset verbose = true "insert assigns sequential versions" begin
            _, _, iteration_id, model_id = _scaffold()

            id1, status1 = DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.NO_STAGE |> Integer, "v1",
            )
            id2, status2 = DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.NO_STAGE |> Integer, "v2",
            )

            @test status1 === DearDiary.Created
            @test status2 === DearDiary.Created

            v1 = DearDiary.fetch(DearDiary.ModelVersion, id1)
            v2 = DearDiary.fetch(DearDiary.ModelVersion, id2)
            @test v1.version == 1
            @test v2.version == 2
        end

        @testset verbose = true "fetch all in version order" begin
            _, _, iteration_id, model_id = _scaffold()
            DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.NO_STAGE |> Integer, "",
            )
            DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.NO_STAGE |> Integer, "",
            )

            versions = DearDiary.fetch_all(DearDiary.ModelVersion, model_id)
            @test versions isa Array{DearDiary.ModelVersion,1}
            @test (versions |> length) == 2
            @test versions[1].version == 1
            @test versions[2].version == 2
        end

        @testset verbose = true "update stage and description" begin
            _, _, iteration_id, model_id = _scaffold()
            version_id, _ = DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.NO_STAGE |> Integer, "",
            )

            update_result = DearDiary.update(
                DearDiary.ModelVersion, version_id;
                stage_id=(DearDiary.STAGING |> Integer),
                description="Ready for review",
            )
            @test update_result === DearDiary.Updated

            version = DearDiary.fetch(DearDiary.ModelVersion, version_id)
            @test version.stage_id == (DearDiary.STAGING |> Integer)
            @test version.description == "Ready for review"
            @test version.updated_date isa DateTime
        end

        @testset verbose = true "archive_production_siblings" begin
            _, _, iteration_id, model_id = _scaffold()
            keep_id, _ = DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.PRODUCTION |> Integer, "",
            )
            other_id, _ = DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.PRODUCTION |> Integer, "",
            )

            @test DearDiary.archive_production_siblings(model_id, keep_id)

            kept = DearDiary.fetch(DearDiary.ModelVersion, keep_id)
            archived = DearDiary.fetch(DearDiary.ModelVersion, other_id)
            @test kept.stage_id == (DearDiary.PRODUCTION |> Integer)
            @test archived.stage_id == (DearDiary.ARCHIVED |> Integer)
        end

        @testset verbose = true "delete" begin
            _, _, iteration_id, model_id = _scaffold()
            version_id, _ = DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.NO_STAGE |> Integer, "",
            )

            @test DearDiary.delete(DearDiary.ModelVersion, version_id)
            @test DearDiary.fetch(DearDiary.ModelVersion, version_id) |> isnothing
        end

        @testset verbose = true "delete_all cascade" begin
            _, _, iteration_id, model_id = _scaffold()
            DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.NO_STAGE |> Integer, "",
            )
            DearDiary.insert(
                DearDiary.ModelVersion,
                model_id, iteration_id, nothing,
                DearDiary.NO_STAGE |> Integer, "",
            )

            @test DearDiary.delete_all(DearDiary.ModelVersion, model_id)
            @test DearDiary.fetch_all(DearDiary.ModelVersion, model_id) |> isempty
        end
    end
end
