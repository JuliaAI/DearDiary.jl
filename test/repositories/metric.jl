@with_deardiary_test_db begin
    @testset verbose = true "metric repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing iteration" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Metric Test Experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                id, status = DearDiary.insert(
                    DearDiary.Metric, iteration_id, "accuracy", 0.95, 0, now()
                )
                @test id isa String
                @test !isempty(id)
                @test status === DearDiary.Created
            end

            @testset "with non-existing iteration" begin
                id, status = DearDiary.insert(
                    DearDiary.Metric,
                    "00000000-0000-0000-0000-000000000000",
                    "accuracy",
                    0.95,
                    0,
                    now(),
                )
                @test isnothing(id)
                @test status === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing metric" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Metric Test Experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                metric_id, _ = DearDiary.insert(
                    DearDiary.Metric, iteration_id, "precision", 0.92, 0, now()
                )

                metric = DearDiary.fetch(DearDiary.Metric, metric_id)

                @test metric isa DearDiary.Metric
                @test metric.id == metric_id
                @test metric.iteration_id == iteration_id
                @test metric.key == "precision"
                @test metric.value == 0.92
                @test metric.step == 0
                @test metric.recorded_at isa DateTime
            end

            @testset "non-existing metric" begin
                metric = DearDiary.fetch(
                    DearDiary.Metric, "00000000-0000-0000-0000-000000000000"
                )

                @test isnothing(metric)
            end
        end

        @testset verbose = true "fetch all is ordered by step ascending" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Metric Test Experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            # Insert out-of-order to make sure the repository, not the caller, sorts.
            DearDiary.insert(DearDiary.Metric, iteration_id, "loss", 0.3, 2, now())
            DearDiary.insert(DearDiary.Metric, iteration_id, "loss", 0.5, 0, now())
            DearDiary.insert(DearDiary.Metric, iteration_id, "loss", 0.4, 1, now())

            metrics = DearDiary.fetch_all(DearDiary.Metric, iteration_id)
            @test metrics isa Array{DearDiary.Metric,1}
            @test (length(metrics)) == 3
            @test [m.step for m in metrics] == [0, 1, 2]
        end

        @testset verbose = true "next_metric_step" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "NextStep Experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)

            @test DearDiary.next_metric_step(iteration_id, "loss") == 0

            DearDiary.insert(DearDiary.Metric, iteration_id, "loss", 0.1, 0, now())
            DearDiary.insert(DearDiary.Metric, iteration_id, "loss", 0.05, 5, now())
            @test DearDiary.next_metric_step(iteration_id, "loss") == 6

            # Per-key counters are independent.
            @test DearDiary.next_metric_step(iteration_id, "accuracy") == 0
        end

        @testset verbose = true "update" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Metric Test Experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            metric_id, _ = DearDiary.insert(
                DearDiary.Metric, iteration_id, "log_loss", 0.001, 0, now()
            )

            update_result = DearDiary.update(
                DearDiary.Metric, metric_id; value=0.0005, step=42
            )

            @test update_result === DearDiary.Updated

            metric = DearDiary.fetch(DearDiary.Metric, metric_id)
            @test metric.value == 0.0005
            @test metric.step == 42
        end

        @testset verbose = true "delete" begin
            @testset "single metric" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Metric Test Experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                metric_id, _ = DearDiary.insert(
                    DearDiary.Metric, iteration_id, "auc", 0.97, 0, now()
                )

                @test DearDiary.delete(DearDiary.Metric, metric_id)
                @test isnothing(DearDiary.fetch(DearDiary.Metric, metric_id))
            end

            @testset "all metrics by iteration" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Metric Test Experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                iteration = DearDiary.get_iteration(iteration_id)
                DearDiary.insert(DearDiary.Metric, iteration_id, "accuracy", 0.93, 0, now())
                DearDiary.insert(
                    DearDiary.Metric, iteration_id, "precision", 0.91, 0, now()
                )

                @test DearDiary.delete(DearDiary.Metric, iteration)

                metrics = DearDiary.fetch_all(DearDiary.Metric, iteration_id)
                @test isempty(metrics)
            end
        end
    end
end
