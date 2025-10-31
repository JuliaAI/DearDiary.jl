@with_trackingapi_test_db begin
    @testset verbose = true "experiment service" begin
        @testset verbose = true "create experiment" begin
            @testset "with existing project" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")

                experiment_id, result = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Service Test Experiment",
                )

                @test experiment_id isa Integer
                @test result isa TrackingAPI.Created
            end

            @testset "with non-existing project" begin
                experiment_id, result = TrackingAPI.create_experiment(
                    9999,
                    TrackingAPI.IN_PROGRESS,
                    "Service Test Experiment",
                )

                @test experiment_id |> isnothing
                @test result isa TrackingAPI.Unprocessable
            end
        end
        @testset verbose = true "get experiment by id" begin
            @testset "existing experiment" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Service Test Experiment",
                )

                experiment = TrackingAPI.get_experiment_by_id(experiment_id)

                @test experiment isa TrackingAPI.Experiment
                @test experiment.id == experiment_id
                @test experiment.project_id == project_id
                @test experiment.status_id == TrackingAPI.IN_PROGRESS |> Integer
                @test experiment.name == "Service Test Experiment"
            end

            @testset "non-existing experiment" begin
                experiment = TrackingAPI.get_experiment_by_id(9999)

                @test experiment |> isnothing
            end
        end

        @testset verbose = true "get experiments" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id1, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Service Test Experiment 1",
            )
            experiment_id2, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.FINISHED,
                "Service Test Experiment 2",
            )

            experiments = TrackingAPI.get_experiments(project_id)

            @test experiments isa Array{TrackingAPI.Experiment,1}
            @test length(experiments) == 2
        end

        @testset verbose = true "update experiment" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Service Test Experiment",
            )

            update_result = TrackingAPI.update_experiment(
                experiment_id,
                TrackingAPI.FINISHED,
                "Updated Service Test Experiment",
                "Updated description",
                Dates.now(),
            )
            @test update_result isa TrackingAPI.Updated

            experiment = TrackingAPI.get_experiment_by_id(experiment_id)

            @test experiment isa TrackingAPI.Experiment
            @test experiment.status_id == TrackingAPI.FINISHED |> Integer
            @test experiment.name == "Updated Service Test Experiment"
            @test experiment.description == "Updated description"
            @test experiment.end_date isa DateTime
        end

        @testset verbose = true "delete experiment" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Service Test Experiment",
            )
            @test TrackingAPI.delete_experiment(experiment_id)
            @test TrackingAPI.get_experiment_by_id(experiment_id) |> isnothing
        end
    end
end
