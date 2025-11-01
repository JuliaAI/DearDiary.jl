@with_tracking_test_db begin
    @testset verbose = true "metric service" begin
        @testset verbose = true "create metric" begin
            @testset "with existing iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)

                metric_id, result = Tracking.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                @test metric_id isa Integer
                @test result isa Tracking.Created
            end

            @testset "with non-existing iteration" begin
                metric_id, result = Tracking.create_metric(
                    9999,
                    "accuracy",
                    0.95,
                )

                @test metric_id |> isnothing
                @test result isa Tracking.Unprocessable
            end
        end

        @testset verbose = true "get metric by id" begin
            @testset "existing metric" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = experiment_id |> Tracking.create_iteration
                metric_id, _ = Tracking.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                metric = metric_id |> Tracking.get_metric

                @test metric isa Tracking.Metric
                @test metric.id == metric_id
                @test metric.iteration_id == iteration_id
                @test metric.key == "accuracy"
                @test metric.value == 0.95
            end

            @testset "non-existing metric" begin
                metric = Tracking.get_metric(9999)

                @test metric |> isnothing
            end
        end

        @testset verbose = true "get metrics" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = Tracking.create_iteration(experiment_id)
            Tracking.create_metric(
                iteration_id,
                "accuracy",
                0.95,
            )
            Tracking.create_metric(
                iteration_id,
                "loss",
                0.05,
            )

            metrics = Tracking.get_metrics(iteration_id)

            @test metrics isa Array{Tracking.Metric,1}
            @test (metrics |> length) == 2
        end

        @testset verbose = true "update metric" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = experiment_id |> Tracking.create_iteration
            metric_id, _ = Tracking.create_metric(
                iteration_id,
                "accuracy",
                0.95,
            )

            metric = metric_id |> Tracking.get_metric

            update_result = Tracking.update_metric(
                metric_id,
                nothing,
                0.98,
            )
            @test update_result isa Tracking.Updated

            updated_metric = metric_id |> Tracking.get_metric

            @test updated_metric.id == metric_id
            @test updated_metric.key == "accuracy"
            @test updated_metric.value == 0.98
        end

        @testset verbose = true "delete metric" begin
            @testset "single metric" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                metric_id, _ = Tracking.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                @test metric_id |> Tracking.delete_metric
                @test (metric_id |> Tracking.get_metric) |> isnothing
            end

            @testset "all metrics by iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                Tracking.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )
                Tracking.create_metric(
                    iteration_id,
                    "loss",
                    0.05,
                )
                iteration = iteration_id |> Tracking.get_iteration

                @test Tracking.delete_metrics(iteration)
                @test Tracking.get_metrics(iteration_id) |> isempty
            end
        end
    end
end
