@with_deardiary_test_db begin
    @testset verbose = true "metric service" begin
        @testset verbose = true "create metric" begin
            @testset "with existing iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                metric_id, result = DearDiary.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                @test metric_id isa Integer
                @test result === DearDiary.Created
            end

            @testset "with non-existing iteration" begin
                metric_id, result = DearDiary.create_metric(
                    9999,
                    "accuracy",
                    0.95,
                )

                @test metric_id |> isnothing
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "get metric by id" begin
            @testset "existing metric" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = experiment_id |> DearDiary.create_iteration
                metric_id, _ = DearDiary.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                metric = metric_id |> DearDiary.get_metric

                @test metric isa DearDiary.Metric
                @test metric.id == metric_id
                @test metric.iteration_id == iteration_id
                @test metric.key == "accuracy"
                @test metric.value == 0.95
            end

            @testset "non-existing metric" begin
                metric = DearDiary.get_metric(9999)

                @test metric |> isnothing
            end
        end

        @testset verbose = true "get metrics" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.create_metric(
                iteration_id,
                "accuracy",
                0.95,
            )
            DearDiary.create_metric(
                iteration_id,
                "loss",
                0.05,
            )

            metrics = DearDiary.get_metrics(iteration_id)

            @test metrics isa Array{DearDiary.Metric,1}
            @test (metrics |> length) == 2
        end

        @testset verbose = true "update metric" begin
            @testset "with non-existing id" begin
                update_result = DearDiary.update_metric(
                    9999,
                    "accuracy",
                    0.98,
                )
                @test update_result === DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = experiment_id |> DearDiary.create_iteration
                metric_id, _ = DearDiary.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                metric = metric_id |> DearDiary.get_metric

                update_result = DearDiary.update_metric(
                    metric_id,
                    nothing,
                    0.98,
                )
                @test update_result === DearDiary.Updated

                updated_metric = metric_id |> DearDiary.get_metric

                @test updated_metric.id == metric_id
                @test updated_metric.key == "accuracy"
                @test updated_metric.value == 0.98
            end
        end

        @testset verbose = true "delete metric" begin
            @testset "single metric" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                metric_id, _ = DearDiary.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )

                @test metric_id |> DearDiary.delete_metric
                @test (metric_id |> DearDiary.get_metric) |> isnothing
            end

            @testset "all metrics by iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                DearDiary.create_metric(
                    iteration_id,
                    "accuracy",
                    0.95,
                )
                DearDiary.create_metric(
                    iteration_id,
                    "loss",
                    0.05,
                )
                iteration = iteration_id |> DearDiary.get_iteration

                @test DearDiary.delete_metrics(iteration)
                @test DearDiary.get_metrics(iteration_id) |> isempty
            end
        end

        @testset verbose = true "get project id" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            metric_id, _ = DearDiary.create_metric(iteration_id, "loss", 0.42)

            @testset "with full ancestor chain" begin
                metric = metric_id |> DearDiary.get_metric
                @test (metric |> DearDiary.get_project_id) == project_id
            end

            @testset "with deleted ancestor iteration" begin
                metric = metric_id |> DearDiary.get_metric
                DearDiary.delete_iteration(iteration_id)
                @test (metric |> DearDiary.get_project_id) |> isnothing
            end
        end
    end
end
