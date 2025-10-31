@with_trackingapi_test_db begin
    @testset verbose = true "metric service" begin
        @testset verbose = true "create metric" begin
            @testset "with existing iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)

                metric_id, result = TrackingAPI.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                @test metric_id isa Integer
                @test result isa TrackingAPI.Created
            end

            @testset "with non-existing iteration" begin
                metric_id, result = TrackingAPI.create_metric(
                    9999,
                    "accuracy",
                    0.95,
                )

                @test metric_id |> isnothing
                @test result isa TrackingAPI.Unprocessable
            end
        end

        @testset verbose = true "get metric by id" begin
            @testset "existing metric" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                metric_id, _ = TrackingAPI.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                metric = TrackingAPI.get_metric_by_id(metric_id)

                @test metric isa TrackingAPI.Metric
                @test metric.id == metric_id
                @test metric.iteration_id == iteration_id
                @test metric.key == "accuracy"
                @test metric.value == 0.95
            end

            @testset "non-existing metric" begin
                metric = TrackingAPI.get_metric_by_id(9999)

                @test metric |> isnothing
            end
        end

        @testset verbose = true "get metrics" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
            TrackingAPI.create_metric(
                iteration_id,
                "accuracy",
                0.95,
            )
            TrackingAPI.create_metric(
                iteration_id,
                "loss",
                0.05,
            )

            metrics = TrackingAPI.get_metrics(iteration_id)

            @test metrics isa Array{TrackingAPI.Metric,1}
            @test (metrics |> length) == 2
        end

        @testset verbose = true "update metric" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
            metric_id, _ = TrackingAPI.create_metric(
                iteration_id,
                "accuracy",
                0.95,
            )

            metric = TrackingAPI.get_metric_by_id(metric_id)

            update_result = TrackingAPI.update_metric(
                metric_id,
                nothing,
                0.98,
            )
            @test update_result isa TrackingAPI.Updated

            updated_metric = TrackingAPI.get_metric_by_id(metric_id)

            @test updated_metric.id == metric_id
            @test updated_metric.key == "accuracy"
            @test updated_metric.value == 0.98
        end

        @testset verbose = true "delete metric" begin
            @testset "single metric" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                metric_id, _ = TrackingAPI.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                @test TrackingAPI.delete_metric(metric_id)
                @test TrackingAPI.get_metric_by_id(metric_id) |> isnothing
            end

            @testset "all metrics by iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                TrackingAPI.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )
                TrackingAPI.create_metric(
                    iteration_id,
                    "loss",
                    0.05,
                )
                iteration = TrackingAPI.get_iteration_by_id(iteration_id)

                @test TrackingAPI.delete_metrics(iteration)
                @test TrackingAPI.get_metrics(iteration_id) |> isempty
            end
        end
    end
end
