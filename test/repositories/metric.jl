@with_trackingapi_test_db begin
    @testset verbose = true "metric repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)

                @test TrackingAPI.insert(
                    TrackingAPI.Metric,
                    iteration_id,
                    "accuracy",
                    0.95,
                ) isa Tuple{Integer,TrackingAPI.Created}
            end

            @testset "with non-existing iteration" begin
                @test TrackingAPI.insert(
                    TrackingAPI.Metric,
                    9999,
                    "accuracy",
                    0.95,
                ) isa Tuple{Nothing,TrackingAPI.Unprocessable}
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing metric" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                metric_id, _ = TrackingAPI.insert(
                    TrackingAPI.Metric,
                    iteration_id,
                    "precision",
                    0.92,
                )

                metric = TrackingAPI.fetch(TrackingAPI.Metric, metric_id)

                @test metric isa TrackingAPI.Metric
                @test metric.id == metric_id
                @test metric.iteration_id == iteration_id
                @test metric.key == "precision"
                @test metric.value == 0.92
            end

            @testset "non-existing metric" begin
                metric = TrackingAPI.fetch(TrackingAPI.Metric, 9999)

                @test metric |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Metric Test Experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
            TrackingAPI.insert(
                TrackingAPI.Metric,
                iteration_id,
                "recall",
                0.88,
            )
            TrackingAPI.insert(
                TrackingAPI.Metric,
                iteration_id,
                "f1_score",
                0.90,
            )
            metrics = TrackingAPI.fetch_all(TrackingAPI.Metric, iteration_id)

            @test metrics isa Array{TrackingAPI.Metric,1}
            @test (metrics |> length) == 2
        end

        @testset verbose = true "update" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Metric Test Experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
            metric_id, _ = TrackingAPI.insert(
                TrackingAPI.Metric,
                iteration_id,
                "log_loss",
                0.001,
            )

            update_result = TrackingAPI.update(
                TrackingAPI.Metric,
                metric_id;
                value=0.0005,
            )

            @test update_result isa TrackingAPI.Updated

            metric = TrackingAPI.fetch(TrackingAPI.Metric, metric_id)
            @test metric.value == 0.0005
        end

        @testset verbose = true "delete" begin
            @testset "single metric" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                metric_id, _ = TrackingAPI.insert(
                    TrackingAPI.Metric,
                    iteration_id,
                    "auc",
                    0.97,
                )

                @test TrackingAPI.delete(TrackingAPI.Metric, metric_id)
                @test TrackingAPI.fetch(TrackingAPI.Metric, metric_id) |> isnothing
            end

            @testset "all metrics by iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                iteration = TrackingAPI.get_iteration_by_id(iteration_id)
                TrackingAPI.insert(
                    TrackingAPI.Metric,
                    iteration_id,
                    "accuracy",
                    0.93,
                )
                TrackingAPI.insert(
                    TrackingAPI.Metric,
                    iteration_id,
                    "precision",
                    0.91,
                )

                @test TrackingAPI.delete(TrackingAPI.Metric, iteration)

                metrics = TrackingAPI.fetch_all(TrackingAPI.Metric, iteration_id)
                @test metrics |> isempty
            end
        end
    end
end
