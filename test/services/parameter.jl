@with_deardiary_test_db begin
    @testset verbose = true "parameter service" begin
        @testset verbose = true "create parameter" begin
            @testset "with existing iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                parameter_id, result = DearDiary.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                @test parameter_id isa Integer
                @test result === DearDiary.Created
            end

            @testset "with non-existing iteration" begin
                parameter_id, result = DearDiary.create_parameter(
                    9999,
                    "learning_rate",
                    0.01,
                )

                @test parameter_id |> isnothing
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "get parameter by id" begin
            @testset "existing parameter" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = experiment_id |> DearDiary.create_iteration
                parameter_id, _ = DearDiary.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                parameter = parameter_id |> DearDiary.get_parameter

                @test parameter isa DearDiary.Parameter
                @test parameter.id == parameter_id
                @test parameter.iteration_id == iteration_id
                @test parameter.key == "learning_rate"
                @test parameter.value == "0.01"
            end

            @testset "non-existing parameter" begin
                parameter = DearDiary.get_parameter(9999)

                @test parameter |> isnothing
            end
        end

        @testset verbose = true "get parameters" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.create_parameter(
                iteration_id,
                "learning_rate",
                0.01,
            )
            DearDiary.create_parameter(
                iteration_id,
                "learning_rate_decay",
                "0.001",
            )

            parameters = DearDiary.get_parameters(iteration_id)

            @test parameters isa Array{DearDiary.Parameter,1}
            @test (parameters |> length) == 2
        end

        @testset verbose = true "update parameter" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_parameter(
                    9999,
                    "momentum",
                    0.9,
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
                parameter_id, _ = DearDiary.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                parameter = parameter_id |> DearDiary.get_parameter

                update_result = DearDiary.update_parameter(
                    parameter_id,
                    nothing,
                    0.001,
                )
                @test update_result === DearDiary.Updated

                updated_parameter = parameter_id |> DearDiary.get_parameter

                @test updated_parameter.id == parameter_id
                @test updated_parameter.key == "learning_rate"
                @test updated_parameter.value == "0.001"
            end
        end

        @testset verbose = true "delete parameter" begin
            @testset "single parameter" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                parameter_id, _ = DearDiary.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                @test parameter_id |> DearDiary.delete_parameter
                @test parameter_id |> DearDiary.get_parameter |> isnothing
            end

            @testset "all parameters by iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                DearDiary.create_parameter(
                    iteration_id,
                    "batch_size",
                    32,
                )
                DearDiary.create_parameter(
                    iteration_id,
                    "learning_rate",
                    0.001,
                )
                iteration = iteration_id |> DearDiary.get_iteration

                @test DearDiary.delete_parameters(iteration)
                @test DearDiary.get_parameters(iteration_id) |> isempty
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
            parameter_id, _ = DearDiary.create_parameter(iteration_id, "lr", "0.001")

            @testset "with full ancestor chain" begin
                parameter = parameter_id |> DearDiary.get_parameter
                @test (parameter |> DearDiary.get_project_id) == project_id
            end

            @testset "with deleted ancestor iteration" begin
                parameter = parameter_id |> DearDiary.get_parameter
                DearDiary.delete_iteration(iteration_id)
                @test (parameter |> DearDiary.get_project_id) |> isnothing
            end
        end
    end
end
