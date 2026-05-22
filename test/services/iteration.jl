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

            @testset "default status is RUNNING with no parent" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Lineage Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Lineage Experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                iteration = iteration_id |> DearDiary.get_iteration

                @test iteration.status_id == (DearDiary.RUNNING |> Integer)
                @test iteration.parent_iteration_id |> isnothing
                @test iteration.error_message |> isempty
            end

            @testset "with parent iteration in same experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Lineage Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Lineage Experiment",
                )
                parent_id, _ = DearDiary.create_iteration(experiment_id)

                child_id, result = DearDiary.create_iteration(
                    experiment_id; parent_iteration_id=parent_id,
                )

                @test child_id isa Integer
                @test result === DearDiary.Created
                child = child_id |> DearDiary.get_iteration
                @test child.parent_iteration_id == parent_id
            end

            @testset "with parent iteration from another experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Lineage Project")
                experiment_a, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Exp A",
                )
                experiment_b, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Exp B",
                )
                parent_id, _ = DearDiary.create_iteration(experiment_a)

                child_id, result = DearDiary.create_iteration(
                    experiment_b; parent_iteration_id=parent_id,
                )
                @test child_id |> isnothing
                @test result === DearDiary.Unprocessable
            end

            @testset "with non-existing parent" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Lineage Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Lineage Experiment",
                )

                child_id, result = DearDiary.create_iteration(
                    experiment_id; parent_iteration_id=9999,
                )
                @test child_id |> isnothing
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "get child iterations" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Children Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Children Experiment",
            )
            parent_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.create_iteration(experiment_id; parent_iteration_id=parent_id)
            DearDiary.create_iteration(experiment_id; parent_iteration_id=parent_id)
            # Unrelated top-level iteration in the same experiment shouldn't appear.
            DearDiary.create_iteration(experiment_id)

            children = parent_id |> DearDiary.get_child_iterations
            @test children isa Array{DearDiary.Iteration,1}
            @test (children |> length) == 2
            @test all(c -> c.parent_iteration_id == parent_id, children)

            # Parent itself has no children of its own once deleted; orphans survive.
            DearDiary.delete_iteration(parent_id)
            survivors = experiment_id |> DearDiary.get_iterations
            orphans = filter(i -> i.parent_iteration_id |> isnothing, survivors)
            # The unrelated top-level iteration plus the two ex-children whose parent
            # pointer was set to NULL by the FK action.
            @test (orphans |> length) == 3
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
                    @test iter.status_id == (DearDiary.RUNNING |> Integer)
                    iter.id
                end

                iteration = captured_id |> DearDiary.get_iteration
                @test !(iteration.end_date |> isnothing)
                @test iteration.status_id == (DearDiary.SUCCEEDED |> Integer)
                @test iteration.error_message |> isempty
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
                @test iteration.status_id == (DearDiary.FAILED |> Integer)
                @test occursin("boom", iteration.error_message)
            end

            @testset "propagates parent_iteration_id" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Withiter Sweep Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Sweep",
                )
                parent_id, _ = DearDiary.create_iteration(experiment_id)

                child_id = DearDiary.with_iteration(
                    experiment_id; parent_iteration_id=parent_id,
                ) do iter
                    iter.id
                end

                child = child_id |> DearDiary.get_iteration
                @test child.parent_iteration_id == parent_id
                @test child.status_id == (DearDiary.SUCCEEDED |> Integer)
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
