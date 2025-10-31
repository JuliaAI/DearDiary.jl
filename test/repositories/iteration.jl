@with_trackingapi_test_db begin
    @testset verbose = true " iteration repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing experiment" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.insert(
                    TrackingAPI.Experiment,
                    project_id,
                    TrackingAPI.IN_PROGRESS |> Integer,
                    "Iteration Test Experiment",
                )

                @test TrackingAPI.insert(
                    TrackingAPI.Iteration,
                    experiment_id,
                ) isa Tuple{Integer,TrackingAPI.Created}
            end

            @testset "with non-existing experiment" begin
                @test TrackingAPI.insert(
                    TrackingAPI.Iteration,
                    9999,
                ) isa Tuple{Nothing,TrackingAPI.Unprocessable}
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.insert(
                    TrackingAPI.Experiment,
                    project_id,
                    TrackingAPI.IN_PROGRESS |> Integer,
                    "Iteration Test Experiment",
                )
                iteration_id, _ = TrackingAPI.insert(TrackingAPI.Iteration, experiment_id)

                iteration = TrackingAPI.fetch(TrackingAPI.Iteration, iteration_id)

                @test iteration isa TrackingAPI.Iteration
                @test iteration.id == iteration_id
                @test iteration.experiment_id == experiment_id
                @test iteration.created_date isa DateTime
            end

            @testset "non-existing iteration" begin
                iteration = TrackingAPI.fetch(TrackingAPI.Iteration, 9999)

                @test iteration |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.insert(
                TrackingAPI.Experiment,
                project_id,
                TrackingAPI.IN_PROGRESS |> Integer,
                "Iteration Test Experiment",
            )
            TrackingAPI.insert(TrackingAPI.Iteration, experiment_id)
            TrackingAPI.insert(TrackingAPI.Iteration, experiment_id)

            iterations = TrackingAPI.fetch_all(TrackingAPI.Iteration, experiment_id)

            @test iterations isa Array{TrackingAPI.Iteration,1}
            @test (iterations |> length) == 2
        end

        @testset verbose = true "update" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.insert(
                TrackingAPI.Experiment,
                project_id,
                TrackingAPI.IN_PROGRESS |> Integer,
                "Iteration Test Experiment",
            )
            iteration_id, _ = TrackingAPI.insert(TrackingAPI.Iteration, experiment_id)

            update_result = TrackingAPI.update(
                TrackingAPI.Iteration, iteration_id;
                notes="Updated notes",
                end_date=Dates.now(),
            )

            @test update_result isa TrackingAPI.Updated

            iteration = TrackingAPI.fetch(TrackingAPI.Iteration, iteration_id)
            @test iteration.notes == "Updated notes"
            @test iteration.end_date isa DateTime
        end

        @testset verbose = true "delete" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.insert(
                TrackingAPI.Experiment,
                project_id,
                TrackingAPI.IN_PROGRESS |> Integer,
                "Iteration Test Experiment",
            )
            iteration_id, _ = TrackingAPI.insert(TrackingAPI.Iteration, experiment_id)

            @test TrackingAPI.delete(TrackingAPI.Iteration, iteration_id)

            iteration = TrackingAPI.fetch(TrackingAPI.Iteration, iteration_id)
            @test iteration |> isnothing
        end
    end
end
