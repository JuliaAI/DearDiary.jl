@with_tracking_test_db begin
    @testset verbose = true "iteration service" begin
        @testset verbose = true "create iteration" begin
            @testset "with existing experiment" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )

                iteration_id, result = Tracking.create_iteration(experiment_id)

                @test iteration_id isa Integer
                @test result isa Tracking.Created
            end

            @testset "with non-existing experiment" begin
                iteration_id, result = Tracking.create_iteration(9999)

                @test iteration_id |> isnothing
                @test result isa Tracking.Unprocessable
            end
        end

        @testset verbose = true "get iteration by id" begin
            @testset "existing iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)

                iteration = iteration_id |> Tracking.get_iteration

                @test iteration isa Tracking.Iteration
                @test iteration.id == iteration_id
                @test iteration.experiment_id == experiment_id
                @test iteration.created_date isa DateTime
            end

            @testset "non-existing iteration" begin
                iteration = Tracking.get_iteration(9999)

                @test iteration |> isnothing
            end
        end

        @testset verbose = true "get iterations" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test experiment",
            )
            Tracking.create_iteration(experiment_id)
            Tracking.create_iteration(experiment_id)

            iterations = Tracking.get_iterations(experiment_id)

            @test iterations isa Array{Tracking.Iteration,1}
            @test length(iterations) == 2
        end

        @testset verbose = true "update iteration" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = Tracking.create_iteration(experiment_id)

            iteration = iteration_id |> Tracking.get_iteration

            @test iteration.notes |> isempty
            @test iteration.created_date isa DateTime
            @test iteration.end_date |> isnothing

            update_result = Tracking.update_iteration(
                iteration_id,
                "Updated iteration notes",
                now(),
            )
            @test update_result isa Tracking.Updated

            updated_iteration = iteration_id |> Tracking.get_iteration

            @test updated_iteration.id == iteration_id
            @test updated_iteration.experiment_id == experiment_id
            @test updated_iteration.notes == "Updated iteration notes"
            @test updated_iteration.created_date isa DateTime
            @test updated_iteration.end_date isa DateTime
        end

        @testset verbose = true "delete iteration" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = Tracking.create_iteration(experiment_id)

            @test Tracking.delete_iteration(iteration_id)
            @test (iteration_id |> Tracking.get_iteration) |> isnothing
        end
    end
end
