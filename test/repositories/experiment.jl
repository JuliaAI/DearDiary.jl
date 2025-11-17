@with_deardiary_test_db begin
    @testset verbose = true "experiment repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing project" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Experiment Project")

                id, status = DearDiary.insert(
                    DearDiary.Experiment,
                    project_id,
                    DearDiary.IN_PROGRESS |> Integer,
                    "Test Experiment",
                )
                @test id isa Integer
                @test status isa DearDiary.Created
            end

            @testset "with non-existing project" begin
                id, status = DearDiary.insert(
                    DearDiary.Experiment,
                    9999,
                    DearDiary.IN_PROGRESS |> Integer,
                    "Test Experiment",
                )
                @test id |> isnothing
                @test status isa DearDiary.Unprocessable
            end

            @testset "with non-allowed status" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Experiment Project")

                id, status = DearDiary.insert(
                    DearDiary.Experiment,
                    project_id,
                    9999,
                    "Test Experiment",
                )
                @test id |> isnothing
                @test status isa DearDiary.Unprocessable
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Experiment Project")
                experiment_id, _ = DearDiary.insert(
                    DearDiary.Experiment,
                    project_id,
                    DearDiary.IN_PROGRESS |> Integer,
                    "Test Experiment",
                )

                experiment = DearDiary.fetch(DearDiary.Experiment, experiment_id)

                @test experiment isa DearDiary.Experiment
                @test experiment.id == experiment_id
                @test experiment.project_id == project_id
                @test experiment.status_id == DearDiary.IN_PROGRESS |> Integer
                @test experiment.name == "Test Experiment"
                @test experiment.created_date isa DateTime
            end

            @testset "non-existing experiment" begin
                experiment = DearDiary.fetch(DearDiary.Experiment, 9999)

                @test experiment |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Experiment Project")
            DearDiary.insert(
                DearDiary.Experiment,
                project_id,
                DearDiary.IN_PROGRESS |> Integer,
                "Test Experiment 1",
            )
            DearDiary.insert(
                DearDiary.Experiment,
                project_id,
                DearDiary.FINISHED |> Integer,
                "Test Experiment 2",
            )

            experiments = DearDiary.fetch_all(DearDiary.Experiment, project_id)

            @test experiments isa Array{DearDiary.Experiment,1}
            @test (experiments |> length) == 2
        end

        @testset verbose = true "update" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Experiment Project")
            experiment_id, _ = DearDiary.insert(
                DearDiary.Experiment,
                project_id,
                DearDiary.IN_PROGRESS |> Integer,
                "Test Experiment",
            )

            update_result = DearDiary.update(
                DearDiary.Experiment, experiment_id;
                status_id=DearDiary.FINISHED |> Integer,
                description="Updated Experiment Description",
                end_date=Dates.now(),
            )

            @test update_result isa DearDiary.Updated

            experiment = DearDiary.fetch(DearDiary.Experiment, experiment_id)

            @test experiment.name == "Test Experiment"
            @test experiment.status_id == DearDiary.FINISHED |> Integer
            @test experiment.description == "Updated Experiment Description"
            @test experiment.end_date isa DateTime
        end

        @testset verbose = true "delete" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Experiment Project")
            experiment_id, _ = DearDiary.insert(
                DearDiary.Experiment,
                project_id,
                DearDiary.IN_PROGRESS |> Integer,
                "Test Experiment",
            )

            @test DearDiary.delete(DearDiary.Experiment, experiment_id)

            experiment = DearDiary.fetch(DearDiary.Experiment, experiment_id)
            @test experiment |> isnothing
        end
    end
end
