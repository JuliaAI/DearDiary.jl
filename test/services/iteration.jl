@with_deardiary_test_db begin
    @testset verbose = true "iteration service" begin
        @testset verbose = true "create iteration" begin
            @testset "with existing experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test experiment"
                )

                iteration_id, result = DearDiary.create_iteration(experiment_id)

                @test iteration_id isa Integer
                @test result === DearDiary.Created
            end

            @testset "with non-existing experiment" begin
                iteration_id, result = DearDiary.create_iteration(9999)

                @test isnothing(iteration_id)
                @test result === DearDiary.Unprocessable
            end

            @testset "default status is RUNNING with no parent" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Lineage Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Lineage Experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                iteration = DearDiary.get_iteration(iteration_id)

                @test iteration.status_id == (Integer(DearDiary.RUNNING))
                @test isnothing(iteration.parent_iteration_id)
                @test isempty(iteration.error_message)
            end

            @testset "with parent iteration in same experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Lineage Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Lineage Experiment"
                )
                parent_id, _ = DearDiary.create_iteration(experiment_id)

                child_id, result = DearDiary.create_iteration(
                    experiment_id; parent_iteration_id=parent_id
                )

                @test child_id isa Integer
                @test result === DearDiary.Created
                child = DearDiary.get_iteration(child_id)
                @test child.parent_iteration_id == parent_id
            end

            @testset "with parent iteration from another experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Lineage Project")
                experiment_a, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Exp A"
                )
                experiment_b, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Exp B"
                )
                parent_id, _ = DearDiary.create_iteration(experiment_a)

                child_id, result = DearDiary.create_iteration(
                    experiment_b; parent_iteration_id=parent_id
                )
                @test isnothing(child_id)
                @test result === DearDiary.Unprocessable
            end

            @testset "with non-existing parent" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Lineage Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Lineage Experiment"
                )

                child_id, result = DearDiary.create_iteration(
                    experiment_id; parent_iteration_id=9999
                )
                @test isnothing(child_id)
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "get child iterations" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Children Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Children Experiment"
            )
            parent_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.create_iteration(experiment_id; parent_iteration_id=parent_id)
            DearDiary.create_iteration(experiment_id; parent_iteration_id=parent_id)
            # Unrelated top-level iteration in the same experiment shouldn't appear.
            DearDiary.create_iteration(experiment_id)

            children = DearDiary.get_child_iterations(parent_id)
            @test children isa Array{DearDiary.Iteration,1}
            @test (length(children)) == 2
            @test all(c -> c.parent_iteration_id == parent_id, children)

            # Parent itself has no children of its own once deleted; orphans survive.
            DearDiary.delete_iteration(parent_id)
            survivors = DearDiary.get_iterations(experiment_id)
            orphans = filter(i -> isnothing(i.parent_iteration_id), survivors)
            # The unrelated top-level iteration plus the two ex-children whose parent
            # pointer was set to NULL by the FK action.
            @test (length(orphans)) == 3
        end

        @testset verbose = true "get iteration by id" begin
            @testset "existing iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                iteration = DearDiary.get_iteration(iteration_id)

                @test iteration isa DearDiary.Iteration
                @test iteration.id == iteration_id
                @test iteration.experiment_id == experiment_id
                @test iteration.created_date isa DateTime
            end

            @testset "non-existing iteration" begin
                iteration = DearDiary.get_iteration(9999)

                @test isnothing(iteration)
            end
        end

        @testset verbose = true "get iterations" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Test experiment"
            )
            DearDiary.create_iteration(experiment_id)
            DearDiary.create_iteration(experiment_id)

            iterations = DearDiary.get_iterations(experiment_id)

            @test iterations isa Array{DearDiary.Iteration,1}
            @test length(iterations) == 2
        end

        @testset verbose = true "update iteration" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_iteration(9999, "Updated iteration notes", now())

                @test result === DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test experiment"
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                iteration = DearDiary.get_iteration(iteration_id)

                @test isempty(iteration.notes)
                @test iteration.created_date isa DateTime
                @test isnothing(iteration.end_date)

                update_result = DearDiary.update_iteration(
                    iteration_id, "Updated iteration notes", now()
                )
                @test update_result === DearDiary.Updated

                updated_iteration = DearDiary.get_iteration(iteration_id)

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
                project_id, DearDiary.IN_PROGRESS, "Test experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)

            @test DearDiary.delete_iteration(iteration_id)
            @test isnothing((DearDiary.get_iteration(iteration_id)))
        end

        @testset verbose = true "with_iteration" begin
            @testset "closes on success" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Withiter Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Withiter Experiment"
                )

                captured_id = DearDiary.with_iteration(experiment_id) do iter
                    @test iter isa DearDiary.Iteration
                    @test isnothing(iter.end_date)
                    @test iter.status_id == (Integer(DearDiary.RUNNING))
                    iter.id
                end

                iteration = DearDiary.get_iteration(captured_id)
                @test !(isnothing(iteration.end_date))
                @test iteration.status_id == (Integer(DearDiary.SUCCEEDED))
                @test isempty(iteration.error_message)
            end

            @testset "closes on failure and rethrows" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Withiter Crash Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Withiter Crash Experiment"
                )

                captured_id = Ref{Int64}(0)
                @test_throws ErrorException DearDiary.with_iteration(experiment_id) do iter
                    captured_id[] = iter.id
                    error("boom")
                end

                iteration = DearDiary.get_iteration(captured_id[])
                @test !(isnothing(iteration.end_date))
                @test iteration.status_id == (Integer(DearDiary.FAILED))
                @test occursin("boom", iteration.error_message)
            end

            @testset "propagates parent_iteration_id" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Withiter Sweep Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Sweep"
                )
                parent_id, _ = DearDiary.create_iteration(experiment_id)

                child_id = DearDiary.with_iteration(
                    experiment_id; parent_iteration_id=parent_id
                ) do iter
                    iter.id
                end

                child = DearDiary.get_iteration(child_id)
                @test child.parent_iteration_id == parent_id
                @test child.status_id == (Integer(DearDiary.SUCCEEDED))
            end

            @testset "raises when experiment cannot accept iterations" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(
                    user.id, "Withiter Stopped Project"
                )
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Stopped Experiment"
                )
                DearDiary.update_experiment(
                    experiment_id, DearDiary.STOPPED, nothing, nothing, nothing
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
                project_id, DearDiary.IN_PROGRESS, "Test experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)

            @testset "with existing parent experiment" begin
                iteration = DearDiary.get_iteration(iteration_id)
                @test (DearDiary.get_project_id(iteration)) == project_id
            end

            @testset "with deleted parent experiment" begin
                iteration = DearDiary.get_iteration(iteration_id)
                DearDiary.delete_experiment(experiment_id)
                @test isnothing((DearDiary.get_project_id(iteration)))
            end
        end
    end
end
