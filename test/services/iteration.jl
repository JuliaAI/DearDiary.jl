@with_trackingapi_test_db begin
    @testset verbose = true "iteration service" begin
        @testset verbose = true "create iteration" begin
            @testset "with existing experiment" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )

                iteration_id, result = TrackingAPI.create_iteration(experiment_id)

                @test iteration_id isa Integer
                @test result isa TrackingAPI.Created
            end

            @testset "with non-existing experiment" begin
                iteration_id, result = TrackingAPI.create_iteration(9999)

                @test iteration_id |> isnothing
                @test result isa TrackingAPI.Unprocessable
            end
        end

        @testset verbose = true "get iteration by id" begin
            @testset "existing iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)

                iteration = TrackingAPI.get_iteration_by_id(iteration_id)

                @test iteration isa TrackingAPI.Iteration
                @test iteration.id == iteration_id
                @test iteration.experiment_id == experiment_id
                @test iteration.created_date isa DateTime
            end

            @testset "non-existing iteration" begin
                iteration = TrackingAPI.get_iteration_by_id(9999)

                @test iteration |> isnothing
            end
        end

        @testset verbose = true "get iterations" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Test experiment",
            )
            TrackingAPI.create_iteration(experiment_id)
            TrackingAPI.create_iteration(experiment_id)

            iterations = TrackingAPI.get_iterations(experiment_id)

            @test iterations isa Array{TrackingAPI.Iteration,1}
            @test length(iterations) == 2
        end

        @testset verbose = true "update iteration" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)

            iteration = TrackingAPI.get_iteration_by_id(iteration_id)

            @test iteration.notes |> isempty
            @test iteration.created_date isa DateTime
            @test iteration.end_date |> isnothing

            update_result = TrackingAPI.update_iteration(
                iteration_id,
                "Updated iteration notes",
                now(),
            )
            @test update_result isa TrackingAPI.Updated

            updated_iteration = TrackingAPI.get_iteration_by_id(iteration_id)

            @test updated_iteration.id == iteration_id
            @test updated_iteration.experiment_id == experiment_id
            @test updated_iteration.notes == "Updated iteration notes"
            @test updated_iteration.created_date isa DateTime
            @test updated_iteration.end_date isa DateTime
        end

        @testset verbose = true "delete iteration" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)

            @test TrackingAPI.delete_iteration(iteration_id)
            @test TrackingAPI.get_iteration_by_id(iteration_id) |> isnothing
        end
    end
end
