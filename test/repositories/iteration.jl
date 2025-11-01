@with_tracking_test_db begin
    @testset verbose = true " iteration repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing experiment" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.insert(
                    Tracking.Experiment,
                    project_id,
                    Tracking.IN_PROGRESS |> Integer,
                    "Iteration Test Experiment",
                )

                @test Tracking.insert(
                    Tracking.Iteration,
                    experiment_id,
                ) isa Tuple{Integer,Tracking.Created}
            end

            @testset "with non-existing experiment" begin
                @test Tracking.insert(
                    Tracking.Iteration,
                    9999,
                ) isa Tuple{Nothing,Tracking.Unprocessable}
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.insert(
                    Tracking.Experiment,
                    project_id,
                    Tracking.IN_PROGRESS |> Integer,
                    "Iteration Test Experiment",
                )
                iteration_id, _ = Tracking.insert(Tracking.Iteration, experiment_id)

                iteration = Tracking.fetch(Tracking.Iteration, iteration_id)

                @test iteration isa Tracking.Iteration
                @test iteration.id == iteration_id
                @test iteration.experiment_id == experiment_id
                @test iteration.created_date isa DateTime
            end

            @testset "non-existing iteration" begin
                iteration = Tracking.fetch(Tracking.Iteration, 9999)

                @test iteration |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.insert(
                Tracking.Experiment,
                project_id,
                Tracking.IN_PROGRESS |> Integer,
                "Iteration Test Experiment",
            )
            Tracking.insert(Tracking.Iteration, experiment_id)
            Tracking.insert(Tracking.Iteration, experiment_id)

            iterations = Tracking.fetch_all(Tracking.Iteration, experiment_id)

            @test iterations isa Array{Tracking.Iteration,1}
            @test (iterations |> length) == 2
        end

        @testset verbose = true "update" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.insert(
                Tracking.Experiment,
                project_id,
                Tracking.IN_PROGRESS |> Integer,
                "Iteration Test Experiment",
            )
            iteration_id, _ = Tracking.insert(Tracking.Iteration, experiment_id)

            update_result = Tracking.update(
                Tracking.Iteration, iteration_id;
                notes="Updated notes",
                end_date=Dates.now(),
            )

            @test update_result isa Tracking.Updated

            iteration = Tracking.fetch(Tracking.Iteration, iteration_id)
            @test iteration.notes == "Updated notes"
            @test iteration.end_date isa DateTime
        end

        @testset verbose = true "delete" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.insert(
                Tracking.Experiment,
                project_id,
                Tracking.IN_PROGRESS |> Integer,
                "Iteration Test Experiment",
            )
            iteration_id, _ = Tracking.insert(Tracking.Iteration, experiment_id)

            @test Tracking.delete(Tracking.Iteration, iteration_id)

            iteration = Tracking.fetch(Tracking.Iteration, iteration_id)
            @test iteration |> isnothing
        end
    end
end
