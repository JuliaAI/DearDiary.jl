@with_deardiary_test_db begin
    @testset verbose = true " iteration repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.insert(
                    DearDiary.Experiment,
                    project_id,
                    DearDiary.IN_PROGRESS |> Integer,
                    "Iteration Test Experiment",
                )

                id, status = DearDiary.insert(
                    DearDiary.Iteration,
                    experiment_id,
                )
                @test id isa Integer
                @test status isa DearDiary.Created
            end

            @testset "with non-existing experiment" begin
                id, status = DearDiary.insert(
                    DearDiary.Iteration,
                    9999,
                )
                @test id |> isnothing
                @test status isa DearDiary.Unprocessable
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.insert(
                    DearDiary.Experiment,
                    project_id,
                    DearDiary.IN_PROGRESS |> Integer,
                    "Iteration Test Experiment",
                )
                iteration_id, _ = DearDiary.insert(DearDiary.Iteration, experiment_id)

                iteration = DearDiary.fetch(DearDiary.Iteration, iteration_id)

                @test iteration isa DearDiary.Iteration
                @test iteration.id == iteration_id
                @test iteration.experiment_id == experiment_id
                @test iteration.created_date isa DateTime
            end

            @testset "non-existing iteration" begin
                iteration = DearDiary.fetch(DearDiary.Iteration, 9999)

                @test iteration |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.insert(
                DearDiary.Experiment,
                project_id,
                DearDiary.IN_PROGRESS |> Integer,
                "Iteration Test Experiment",
            )
            DearDiary.insert(DearDiary.Iteration, experiment_id)
            DearDiary.insert(DearDiary.Iteration, experiment_id)

            iterations = DearDiary.fetch_all(DearDiary.Iteration, experiment_id)

            @test iterations isa Array{DearDiary.Iteration,1}
            @test (iterations |> length) == 2
        end

        @testset verbose = true "update" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.insert(
                DearDiary.Experiment,
                project_id,
                DearDiary.IN_PROGRESS |> Integer,
                "Iteration Test Experiment",
            )
            iteration_id, _ = DearDiary.insert(DearDiary.Iteration, experiment_id)

            update_result = DearDiary.update(
                DearDiary.Iteration, iteration_id;
                notes="Updated notes",
                end_date=Dates.now(),
            )

            @test update_result isa DearDiary.Updated

            iteration = DearDiary.fetch(DearDiary.Iteration, iteration_id)
            @test iteration.notes == "Updated notes"
            @test iteration.end_date isa DateTime
        end

        @testset verbose = true "delete" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.insert(
                DearDiary.Experiment,
                project_id,
                DearDiary.IN_PROGRESS |> Integer,
                "Iteration Test Experiment",
            )
            iteration_id, _ = DearDiary.insert(DearDiary.Iteration, experiment_id)

            @test DearDiary.delete(DearDiary.Iteration, iteration_id)

            iteration = DearDiary.fetch(DearDiary.Iteration, iteration_id)
            @test iteration |> isnothing
        end
    end
end
