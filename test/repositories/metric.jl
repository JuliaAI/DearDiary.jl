@with_deardiary_test_db begin
    @testset verbose = true "metric repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                id, status = DearDiary.insert(
                    DearDiary.Metric,
                    iteration_id,
                    "accuracy",
                    0.95,
                )
                @test id isa Integer
                @test status isa DearDiary.Created
            end

            @testset "with non-existing iteration" begin
                id, status = DearDiary.insert(
                    DearDiary.Metric,
                    9999,
                    "accuracy",
                    0.95,
                )
                @test id |> isnothing
                @test status isa DearDiary.Unprocessable
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing metric" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                metric_id, _ = DearDiary.insert(
                    DearDiary.Metric,
                    iteration_id,
                    "precision",
                    0.92,
                )

                metric = DearDiary.fetch(DearDiary.Metric, metric_id)

                @test metric isa DearDiary.Metric
                @test metric.id == metric_id
                @test metric.iteration_id == iteration_id
                @test metric.key == "precision"
                @test metric.value == 0.92
            end

            @testset "non-existing metric" begin
                metric = DearDiary.fetch(DearDiary.Metric, 9999)

                @test metric |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Metric Test Experiment",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.insert(
                DearDiary.Metric,
                iteration_id,
                "recall",
                0.88,
            )
            DearDiary.insert(
                DearDiary.Metric,
                iteration_id,
                "f1_score",
                0.90,
            )
            metrics = DearDiary.fetch_all(DearDiary.Metric, iteration_id)

            @test metrics isa Array{DearDiary.Metric,1}
            @test (metrics |> length) == 2
        end

        @testset verbose = true "update" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Metric Test Experiment",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            metric_id, _ = DearDiary.insert(
                DearDiary.Metric,
                iteration_id,
                "log_loss",
                0.001,
            )

            update_result = DearDiary.update(
                DearDiary.Metric,
                metric_id;
                value=0.0005,
            )

            @test update_result isa DearDiary.Updated

            metric = DearDiary.fetch(DearDiary.Metric, metric_id)
            @test metric.value == 0.0005
        end

        @testset verbose = true "delete" begin
            @testset "single metric" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                metric_id, _ = DearDiary.insert(
                    DearDiary.Metric,
                    iteration_id,
                    "auc",
                    0.97,
                )

                @test DearDiary.delete(DearDiary.Metric, metric_id)
                @test DearDiary.fetch(DearDiary.Metric, metric_id) |> isnothing
            end

            @testset "all metrics by iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Metric Test Experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                iteration = iteration_id |> DearDiary.get_iteration
                DearDiary.insert(
                    DearDiary.Metric,
                    iteration_id,
                    "accuracy",
                    0.93,
                )
                DearDiary.insert(
                    DearDiary.Metric,
                    iteration_id,
                    "precision",
                    0.91,
                )

                @test DearDiary.delete(DearDiary.Metric, iteration)

                metrics = DearDiary.fetch_all(DearDiary.Metric, iteration_id)
                @test metrics |> isempty
            end
        end
    end
end
