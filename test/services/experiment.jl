@with_tracking_test_db begin
    @testset verbose = true "experiment service" begin
        @testset verbose = true "create experiment" begin
            @testset "with existing project" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")

                experiment_id, result = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Service Test Experiment",
                )

                @test experiment_id isa Integer
                @test result isa Tracking.Created
            end

            @testset "with non-existing project" begin
                experiment_id, result = Tracking.create_experiment(
                    9999,
                    Tracking.IN_PROGRESS,
                    "Service Test Experiment",
                )

                @test experiment_id |> isnothing
                @test result isa Tracking.Unprocessable
            end
        end
        @testset verbose = true "get experiment by id" begin
            @testset "existing experiment" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Service Test Experiment",
                )

                experiment = experiment_id |> Tracking.get_experiment

                @test experiment isa Tracking.Experiment
                @test experiment.id == experiment_id
                @test experiment.project_id == project_id
                @test experiment.status_id == Tracking.IN_PROGRESS |> Integer
                @test experiment.name == "Service Test Experiment"
            end

            @testset "non-existing experiment" begin
                experiment = Tracking.get_experiment(9999)

                @test experiment |> isnothing
            end
        end

        @testset verbose = true "get experiments" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id1, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Service Test Experiment 1",
            )
            experiment_id2, _ = Tracking.create_experiment(
                project_id,
                Tracking.FINISHED,
                "Service Test Experiment 2",
            )

            experiments = Tracking.get_experiments(project_id)

            @test experiments isa Array{Tracking.Experiment,1}
            @test length(experiments) == 2
        end

        @testset verbose = true "update experiment" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Service Test Experiment",
            )

            update_result = Tracking.update_experiment(
                experiment_id,
                Tracking.FINISHED,
                "Updated Service Test Experiment",
                "Updated description",
                Dates.now(),
            )
            @test update_result isa Tracking.Updated

            experiment = experiment_id |> Tracking.get_experiment

            @test experiment isa Tracking.Experiment
            @test experiment.status_id == Tracking.FINISHED |> Integer
            @test experiment.name == "Updated Service Test Experiment"
            @test experiment.description == "Updated description"
            @test experiment.end_date isa DateTime
        end

        @testset verbose = true "delete experiment" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Service Test Experiment",
            )
            @test Tracking.delete_experiment(experiment_id)
            @test (experiment_id |> Tracking.get_experiment) |> isnothing
        end
    end
end
