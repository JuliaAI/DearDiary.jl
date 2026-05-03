@with_deardiary_test_db begin
    @testset verbose = true "experiment service" begin
        @testset verbose = true "create experiment" begin
            @testset "with existing project" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")

                experiment_id, result = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Service Test Experiment",
                )

                @test experiment_id isa Integer
                @test result isa DearDiary.Created
            end

            @testset "with non-existing project" begin
                experiment_id, result = DearDiary.create_experiment(
                    9999,
                    DearDiary.IN_PROGRESS,
                    "Service Test Experiment",
                )

                @test experiment_id |> isnothing
                @test result isa DearDiary.Unprocessable
            end

            @testset "with invalid status" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")

                experiment_id, result = DearDiary.create_experiment(
                    project_id,
                    9999,
                    "Service Test Experiment",
                )

                @test experiment_id |> isnothing
                @test result isa DearDiary.Unprocessable
            end
        end
        @testset verbose = true "get experiment by id" begin
            @testset "existing experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Service Test Experiment",
                )

                experiment = experiment_id |> DearDiary.get_experiment

                @test experiment isa DearDiary.Experiment
                @test experiment.id == experiment_id
                @test experiment.project_id == project_id
                @test experiment.status_id == DearDiary.IN_PROGRESS |> Integer
                @test experiment.name == "Service Test Experiment"
            end

            @testset "non-existing experiment" begin
                experiment = DearDiary.get_experiment(9999)

                @test experiment |> isnothing
            end
        end

        @testset verbose = true "get experiments" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id1, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Service Test Experiment 1",
            )
            experiment_id2, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.FINISHED,
                "Service Test Experiment 2",
            )

            experiments = DearDiary.get_experiments(project_id)

            @test experiments isa Array{DearDiary.Experiment,1}
            @test length(experiments) == 2
        end

        @testset verbose = true "update experiment" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_experiment(
                    9999,
                    DearDiary.FINISHED,
                    "Updated Experiment",
                    "Updated description",
                    Dates.now(),
                )

                @test result isa DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Service Test Experiment",
                )

                update_result = DearDiary.update_experiment(
                    experiment_id,
                    DearDiary.FINISHED,
                    "Updated Service Test Experiment",
                    "Updated description",
                    Dates.now(),
                )
                @test update_result isa DearDiary.Updated

                experiment = experiment_id |> DearDiary.get_experiment

                @test experiment isa DearDiary.Experiment
                @test experiment.status_id == DearDiary.FINISHED |> Integer
                @test experiment.name == "Updated Service Test Experiment"
                @test experiment.description == "Updated description"
                @test experiment.end_date isa DateTime
            end

            @testset "with invalid status" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Service Test Experiment",
                )

                result = DearDiary.update_experiment(
                    experiment_id,
                    9999,
                    "Updated Experiment",
                    "Updated description",
                    Dates.now(),
                )

                @test result isa DearDiary.Unprocessable
            end
        end

        @testset verbose = true "delete experiment" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Service Test Experiment",
            )
            DearDiary.create_iteration(experiment_id)
            DearDiary.create_resource(
                experiment_id,
                "Test Resource",
                UInt8[0x00, 0x01, 0x02],
            )

            @test DearDiary.delete_experiment(experiment_id)
            @test (experiment_id |> DearDiary.get_experiment) |> isnothing
        end

        @testset verbose = true "get project id" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test experiment",
            )

            experiment = experiment_id |> DearDiary.get_experiment
            @test (experiment |> DearDiary.get_project_id) == project_id
        end

        @testset verbose = true "get experiments paginated" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Pagination Project")
            for i in 1:5
                DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Exp $(i)",
                )
            end

            page = DearDiary.get_experiments(project_id, DearDiary.Pagination(2, 0))
            @test page isa DearDiary.PaginatedResponse{DearDiary.Experiment}
            @test (page.data |> length) == 2
            @test page.total == 5
            @test page.limit == 2
            @test page.offset == 0

            page2 = DearDiary.get_experiments(project_id, DearDiary.Pagination(2, 2))
            @test (page2.data |> length) == 2
            @test page2.offset == 2
            @test page.data[1].id != page2.data[1].id

            beyond = DearDiary.get_experiments(project_id, DearDiary.Pagination(10, 99))
            @test beyond.data |> isempty
            @test beyond.total == 5
        end
    end
end
