@with_tracking_test_db begin
    @testset verbose = true "metric repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)

                @test Tracking.insert(
                    Tracking.Metric,
                    iteration_id,
                    "accuracy",
                    0.95,
                ) isa Tuple{Integer,Tracking.Created}
            end

            @testset "with non-existing iteration" begin
                @test Tracking.insert(
                    Tracking.Metric,
                    9999,
                    "accuracy",
                    0.95,
                ) isa Tuple{Nothing,Tracking.Unprocessable}
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing metric" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                metric_id, _ = Tracking.insert(
                    Tracking.Metric,
                    iteration_id,
                    "precision",
                    0.92,
                )

                metric = Tracking.fetch(Tracking.Metric, metric_id)

                @test metric isa Tracking.Metric
                @test metric.id == metric_id
                @test metric.iteration_id == iteration_id
                @test metric.key == "precision"
                @test metric.value == 0.92
            end

            @testset "non-existing metric" begin
                metric = Tracking.fetch(Tracking.Metric, 9999)

                @test metric |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Metric Test Experiment",
            )
            iteration_id, _ = Tracking.create_iteration(experiment_id)
            Tracking.insert(
                Tracking.Metric,
                iteration_id,
                "recall",
                0.88,
            )
            Tracking.insert(
                Tracking.Metric,
                iteration_id,
                "f1_score",
                0.90,
            )
            metrics = Tracking.fetch_all(Tracking.Metric, iteration_id)

            @test metrics isa Array{Tracking.Metric,1}
            @test (metrics |> length) == 2
        end

        @testset verbose = true "update" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Metric Test Experiment",
            )
            iteration_id, _ = Tracking.create_iteration(experiment_id)
            metric_id, _ = Tracking.insert(
                Tracking.Metric,
                iteration_id,
                "log_loss",
                0.001,
            )

            update_result = Tracking.update(
                Tracking.Metric,
                metric_id;
                value=0.0005,
            )

            @test update_result isa Tracking.Updated

            metric = Tracking.fetch(Tracking.Metric, metric_id)
            @test metric.value == 0.0005
        end

        @testset verbose = true "delete" begin
            @testset "single metric" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                metric_id, _ = Tracking.insert(
                    Tracking.Metric,
                    iteration_id,
                    "auc",
                    0.97,
                )

                @test Tracking.delete(Tracking.Metric, metric_id)
                @test Tracking.fetch(Tracking.Metric, metric_id) |> isnothing
            end

            @testset "all metrics by iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                iteration = iteration_id |> Tracking.get_iteration
                Tracking.insert(
                    Tracking.Metric,
                    iteration_id,
                    "accuracy",
                    0.93,
                )
                Tracking.insert(
                    Tracking.Metric,
                    iteration_id,
                    "precision",
                    0.91,
                )

                @test Tracking.delete(Tracking.Metric, iteration)

                metrics = Tracking.fetch_all(Tracking.Metric, iteration_id)
                @test metrics |> isempty
            end
        end
    end
end
