@with_tracking_test_db begin
    @testset verbose = true "experiment repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing project" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Experiment Project")

                @test Tracking.insert(
                    Tracking.Experiment,
                    project_id,
                    Tracking.IN_PROGRESS |> Integer,
                    "Test Experiment",
                ) isa Tuple{Integer,Tracking.Created}
            end

            @testset "with non-existing project" begin
                @test Tracking.insert(
                    Tracking.Experiment,
                    9999,
                    Tracking.IN_PROGRESS |> Integer,
                    "Test Experiment",
                ) isa Tuple{Nothing,Tracking.Unprocessable}
            end

            @testset "with non-allowed status" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Experiment Project")

                @test Tracking.insert(
                    Tracking.Experiment,
                    project_id,
                    9999,
                    "Test Experiment",
                ) isa Tuple{Nothing,Tracking.Unprocessable}
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing experiment" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Experiment Project")
                experiment_id, _ = Tracking.insert(
                    Tracking.Experiment,
                    project_id,
                    Tracking.IN_PROGRESS |> Integer,
                    "Test Experiment",
                )

                experiment = Tracking.fetch(Tracking.Experiment, experiment_id)

                @test experiment isa Tracking.Experiment
                @test experiment.id == experiment_id
                @test experiment.project_id == project_id
                @test experiment.status_id == Tracking.IN_PROGRESS |> Integer
                @test experiment.name == "Test Experiment"
                @test experiment.created_date isa DateTime
            end

            @testset "non-existing experiment" begin
                experiment = Tracking.fetch(Tracking.Experiment, 9999)

                @test experiment |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Experiment Project")
            Tracking.insert(
                Tracking.Experiment,
                project_id,
                Tracking.IN_PROGRESS |> Integer,
                "Test Experiment 1",
            )
            Tracking.insert(
                Tracking.Experiment,
                project_id,
                Tracking.FINISHED |> Integer,
                "Test Experiment 2",
            )

            experiments = Tracking.fetch_all(Tracking.Experiment, project_id)

            @test experiments isa Array{Tracking.Experiment,1}
            @test (experiments |> length) == 2
        end

        @testset verbose = true "update" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Experiment Project")
            experiment_id, _ = Tracking.insert(
                Tracking.Experiment,
                project_id,
                Tracking.IN_PROGRESS |> Integer,
                "Test Experiment",
            )

            update_result = Tracking.update(
                Tracking.Experiment, experiment_id;
                status_id=Tracking.FINISHED |> Integer,
                description="Updated Experiment Description",
                end_date=Dates.now(),
            )

            @test update_result isa Tracking.Updated

            experiment = Tracking.fetch(Tracking.Experiment, experiment_id)

            @test experiment.name == "Test Experiment"
            @test experiment.status_id == Tracking.FINISHED |> Integer
            @test experiment.description == "Updated Experiment Description"
            @test experiment.end_date isa DateTime
        end

        @testset verbose = true "delete" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Experiment Project")
            experiment_id, _ = Tracking.insert(
                Tracking.Experiment,
                project_id,
                Tracking.IN_PROGRESS |> Integer,
                "Test Experiment",
            )

            @test Tracking.delete(Tracking.Experiment, experiment_id)

            experiment = Tracking.fetch(Tracking.Experiment, experiment_id)
            @test experiment |> isnothing
        end
    end
end
