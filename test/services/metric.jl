@with_deardiary_test_db begin
    @testset verbose = true "metric service" begin
        @testset verbose = true "create metric" begin
            @testset "with existing iteration" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                metric_id, result = DearDiary.create_metric(iteration_id, "accuracy", 0.95)

                @test metric_id isa String
                @test !isempty(metric_id)
                @test result === DearDiary.Created
            end

            @testset "with non-existing iteration" begin
                metric_id, result = DearDiary.create_metric(
                    "00000000-0000-0000-0000-000000000000", "accuracy", 0.95
                )

                @test isnothing(metric_id)
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "get metric by id" begin
            @testset "existing metric" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                metric_id, _ = DearDiary.create_metric(iteration_id, "accuracy", 0.95)

                metric = DearDiary.get_metric(metric_id)

                @test metric isa DearDiary.Metric
                @test metric.id == metric_id
                @test metric.iteration_id == iteration_id
                @test metric.key == "accuracy"
                @test metric.value == 0.95
            end

            @testset "non-existing metric" begin
                metric = DearDiary.get_metric("00000000-0000-0000-0000-000000000000")

                @test isnothing(metric)
            end
        end

        @testset verbose = true "get metrics" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Test experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.create_metric(iteration_id, "accuracy", 0.95)
            DearDiary.create_metric(iteration_id, "loss", 0.05)

            metrics = DearDiary.get_metrics(iteration_id)

            @test metrics isa Array{DearDiary.Metric,1}
            @test (length(metrics)) == 2
        end

        @testset verbose = true "update metric" begin
            @testset "with non-existing id" begin
                update_result = DearDiary.update_metric(
                    "00000000-0000-0000-0000-000000000000", "accuracy", 0.98
                )
                @test update_result === DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                metric_id, _ = DearDiary.create_metric(iteration_id, "accuracy", 0.95)

                metric = DearDiary.get_metric(metric_id)

                update_result = DearDiary.update_metric(metric_id, nothing, 0.98)
                @test update_result === DearDiary.Updated

                updated_metric = DearDiary.get_metric(metric_id)

                @test updated_metric.id == metric_id
                @test updated_metric.key == "accuracy"
                @test updated_metric.value == 0.98
            end
        end

        @testset verbose = true "delete metric" begin
            @testset "single metric" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                metric_id, _ = DearDiary.create_metric(iteration_id, "accuracy", 0.95)

                @test DearDiary.delete_metric(metric_id)
                @test isnothing((DearDiary.get_metric(metric_id)))
            end

            @testset "all metrics by iteration" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                DearDiary.create_metric(iteration_id, "accuracy", 0.95)
                DearDiary.create_metric(iteration_id, "loss", 0.05)
                iteration = DearDiary.get_iteration(iteration_id)

                @test DearDiary.delete_metrics(iteration)
                @test isempty(DearDiary.get_metrics(iteration_id))
            end
        end

        @testset verbose = true "step and recorded_at semantics" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "StepProject")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Step experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)

            @testset "step defaults to next per-key" begin
                # First insert under "loss" gets step 0.
                id1, _ = DearDiary.create_metric(iteration_id, "loss", 0.5)
                id2, _ = DearDiary.create_metric(iteration_id, "loss", 0.4)
                id3, _ = DearDiary.create_metric(iteration_id, "loss", 0.3)
                metrics = DearDiary.get_metrics(iteration_id)
                losses = [m for m in metrics if m.key == "loss"]
                @test [m.step for m in losses] == [0, 1, 2]
                @test [m.value for m in losses] == [0.5, 0.4, 0.3]

                # Per-key counters are independent.
                id, _ = DearDiary.create_metric(iteration_id, "accuracy", 0.9)
                accuracy = DearDiary.get_metric(id)
                @test accuracy.step == 0
            end

            @testset "explicit step is honored" begin
                id, _ = DearDiary.create_metric(iteration_id, "explicit_step", 1.0; step=42)
                @test DearDiary.get_metric(id).step == 42
            end

            @testset "recorded_at defaults to now()" begin
                before = now()
                id, _ = DearDiary.create_metric(iteration_id, "ts_default", 1.0)
                after = now()
                metric = DearDiary.get_metric(id)
                @test metric.recorded_at >= before
                @test metric.recorded_at <= after
            end

            @testset "explicit recorded_at is honored" begin
                explicit = DateTime(2025, 1, 1, 12, 0, 0)
                id, _ = DearDiary.create_metric(
                    iteration_id, "ts_explicit", 1.0; recorded_at=explicit
                )
                @test DearDiary.get_metric(id).recorded_at == explicit
            end
        end

        @testset verbose = true "log_metrics batch" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "BatchProject")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Batch experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)

            @testset "shared step + recorded_at" begin
                recorded = DateTime(2025, 6, 15, 9, 0, 0)
                result = DearDiary.log_metrics(
                    iteration_id,
                    Dict("loss" => 0.31, "accuracy" => 0.94);
                    step=7,
                    recorded_at=recorded,
                )
                @test result.status === DearDiary.Created
                @test (length(result.ids)) == 2

                inserted = [DearDiary.get_metric(id) for id in result.ids]
                @test all(m -> m.step == 7, inserted)
                @test all(m -> m.recorded_at == recorded, inserted)
            end

            @testset "per-key auto step when step omitted" begin
                DearDiary.log_metrics(iteration_id, Dict("rolling" => 0.1);)
                DearDiary.log_metrics(iteration_id, Dict("rolling" => 0.2);)
                rolling = [
                    m for m in DearDiary.get_metrics(iteration_id) if m.key == "rolling"
                ]
                @test [m.step for m in rolling] == [0, 1]
            end

            @testset "refuses ended iteration" begin
                ended_iteration_id, _ = DearDiary.create_iteration(experiment_id)
                DearDiary.update_iteration(ended_iteration_id, nothing, now())

                result = DearDiary.log_metrics(ended_iteration_id, Dict("loss" => 0.5);)
                @test result.status === DearDiary.Unprocessable
                @test isempty(result.ids)
            end
        end

        @testset verbose = true "get project id" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Test experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            metric_id, _ = DearDiary.create_metric(iteration_id, "loss", 0.42)

            @testset "with full ancestor chain" begin
                metric = DearDiary.get_metric(metric_id)
                @test (DearDiary.get_project_id(metric)) == project_id
            end

            @testset "with deleted ancestor iteration" begin
                metric = DearDiary.get_metric(metric_id)
                DearDiary.delete_iteration(iteration_id)
                @test isnothing((DearDiary.get_project_id(metric)))
            end
        end
    end
end
