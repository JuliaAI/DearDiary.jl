@with_trackingapi_test_db begin
    @testset verbose = true "experiment repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing project" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Experiment Project")

                @test TrackingAPI.insert(
                    TrackingAPI.Experiment,
                    project_id,
                    TrackingAPI.IN_PROGRESS |> Integer,
                    "Test Experiment",
                ) isa Tuple{Integer,TrackingAPI.Created}
            end

            @testset "with non-existing project" begin
                @test TrackingAPI.insert(
                    TrackingAPI.Experiment,
                    9999,
                    TrackingAPI.IN_PROGRESS |> Integer,
                    "Test Experiment",
                ) isa Tuple{Nothing,TrackingAPI.Unprocessable}
            end

            @testset "with non-allowed status" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Experiment Project")

                @test TrackingAPI.insert(
                    TrackingAPI.Experiment,
                    project_id,
                    9999,
                    "Test Experiment",
                ) isa Tuple{Nothing,TrackingAPI.Unprocessable}
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing experiment" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Experiment Project")
                experiment_id, _ = TrackingAPI.insert(
                    TrackingAPI.Experiment,
                    project_id,
                    TrackingAPI.IN_PROGRESS |> Integer,
                    "Test Experiment",
                )

                experiment = TrackingAPI.fetch(TrackingAPI.Experiment, experiment_id)

                @test experiment isa TrackingAPI.Experiment
                @test experiment.id == experiment_id
                @test experiment.project_id == project_id
                @test experiment.status_id == TrackingAPI.IN_PROGRESS |> Integer
                @test experiment.name == "Test Experiment"
                @test experiment.created_date isa DateTime
            end

            @testset "non-existing experiment" begin
                experiment = TrackingAPI.fetch(TrackingAPI.Experiment, 9999)

                @test experiment |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Experiment Project")
            TrackingAPI.insert(
                TrackingAPI.Experiment,
                project_id,
                TrackingAPI.IN_PROGRESS |> Integer,
                "Test Experiment 1",
            )
            TrackingAPI.insert(
                TrackingAPI.Experiment,
                project_id,
                TrackingAPI.FINISHED |> Integer,
                "Test Experiment 2",
            )

            experiments = TrackingAPI.fetch_all(TrackingAPI.Experiment, project_id)

            @test experiments isa Array{TrackingAPI.Experiment,1}
            @test (experiments |> length) == 2
        end

        @testset verbose = true "update" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Experiment Project")
            experiment_id, _ = TrackingAPI.insert(
                TrackingAPI.Experiment,
                project_id,
                TrackingAPI.IN_PROGRESS |> Integer,
                "Test Experiment",
            )

            update_result = TrackingAPI.update(
                TrackingAPI.Experiment, experiment_id;
                status_id=TrackingAPI.FINISHED |> Integer,
                description="Updated Experiment Description",
                end_date=Dates.now(),
            )

            @test update_result isa TrackingAPI.Updated

            experiment = TrackingAPI.fetch(TrackingAPI.Experiment, experiment_id)

            @test experiment.name == "Test Experiment"
            @test experiment.status_id == TrackingAPI.FINISHED |> Integer
            @test experiment.description == "Updated Experiment Description"
            @test experiment.end_date isa DateTime
        end

        @testset verbose = true "delete" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Experiment Project")
            experiment_id, _ = TrackingAPI.insert(
                TrackingAPI.Experiment,
                project_id,
                TrackingAPI.IN_PROGRESS |> Integer,
                "Test Experiment",
            )

            @test TrackingAPI.delete(TrackingAPI.Experiment, experiment_id)

            experiment = TrackingAPI.fetch(TrackingAPI.Experiment, experiment_id)
            @test experiment |> isnothing
        end
    end
end
