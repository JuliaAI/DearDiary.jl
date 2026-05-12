@with_deardiary_test_db begin
    @testset verbose = true "iteration service" begin
        @testset verbose = true "create iteration" begin
            @testset "with existing experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )

                iteration_id, result = DearDiary.create_iteration(experiment_id)

                @test iteration_id isa Integer
                @test result === DearDiary.Created
            end

            @testset "with non-existing experiment" begin
                iteration_id, result = DearDiary.create_iteration(9999)

                @test iteration_id |> isnothing
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "get iteration by id" begin
            @testset "existing iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                iteration = iteration_id |> DearDiary.get_iteration

                @test iteration isa DearDiary.Iteration
                @test iteration.id == iteration_id
                @test iteration.experiment_id == experiment_id
                @test iteration.created_date isa DateTime
            end

            @testset "non-existing iteration" begin
                iteration = DearDiary.get_iteration(9999)

                @test iteration |> isnothing
            end
        end

        @testset verbose = true "get iterations" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test experiment",
            )
            DearDiary.create_iteration(experiment_id)
            DearDiary.create_iteration(experiment_id)

            iterations = DearDiary.get_iterations(experiment_id)

            @test iterations isa Array{DearDiary.Iteration,1}
            @test length(iterations) == 2
        end

        @testset verbose = true "update iteration" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_iteration(
                    9999,
                    "Updated iteration notes",
                    now(),
                )

                @test result === DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                iteration = iteration_id |> DearDiary.get_iteration

                @test iteration.notes |> isempty
                @test iteration.created_date isa DateTime
                @test iteration.end_date |> isnothing

                update_result = DearDiary.update_iteration(
                    iteration_id,
                    "Updated iteration notes",
                    now(),
                )
                @test update_result === DearDiary.Updated

                updated_iteration = iteration_id |> DearDiary.get_iteration

                @test updated_iteration.id == iteration_id
                @test updated_iteration.experiment_id == experiment_id
                @test updated_iteration.notes == "Updated iteration notes"
                @test updated_iteration.created_date isa DateTime
                @test updated_iteration.end_date isa DateTime
            end
        end

        @testset verbose = true "delete iteration" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)

            @test DearDiary.delete_iteration(iteration_id)
            @test (iteration_id |> DearDiary.get_iteration) |> isnothing
        end

        @testset verbose = true "with_iteration" begin
            @testset "closes on success" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Withiter Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Withiter Experiment",
                )

                captured_id = DearDiary.with_iteration(experiment_id) do iter
                    @test iter isa DearDiary.Iteration
                    @test iter.end_date |> isnothing
                    iter.id
                end

                iteration = captured_id |> DearDiary.get_iteration
                @test !(iteration.end_date |> isnothing)
            end

            @testset "closes on failure and rethrows" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Withiter Crash Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Withiter Crash Experiment",
                )

                captured_id = Ref{Int64}(0)
                @test_throws ErrorException DearDiary.with_iteration(experiment_id) do iter
                    captured_id[] = iter.id
                    error("boom")
                end

                iteration = captured_id[] |> DearDiary.get_iteration
                @test !(iteration.end_date |> isnothing)
            end

            @testset "raises when experiment cannot accept iterations" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Withiter Stopped Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Stopped Experiment",
                )
                DearDiary.update_experiment(
                    experiment_id, DearDiary.STOPPED, nothing, nothing, nothing,
                )

                @test_throws ArgumentError DearDiary.with_iteration(experiment_id) do _
                    error("should not run")
                end
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

            @testset "with existing parent experiment" begin
                iteration = iteration_id |> DearDiary.get_iteration
                @test (iteration |> DearDiary.get_project_id) == project_id
            end

            @testset "with deleted parent experiment" begin
                iteration = iteration_id |> DearDiary.get_iteration
                DearDiary.delete_experiment(experiment_id)
                @test (iteration |> DearDiary.get_project_id) |> isnothing
            end
        end
    end
end
