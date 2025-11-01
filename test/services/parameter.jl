@with_tracking_test_db begin
    @testset verbose = true "parameter service" begin
        @testset verbose = true "create parameter" begin
            @testset "with existing iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)

                parameter_id, result = Tracking.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                @test parameter_id isa Integer
                @test result isa Tracking.Created
            end

            @testset "with non-existing iteration" begin
                parameter_id, result = Tracking.create_parameter(
                    9999,
                    "learning_rate",
                    0.01,
                )

                @test parameter_id |> isnothing
                @test result isa Tracking.Unprocessable
            end
        end

        @testset verbose = true "get parameter by id" begin
            @testset "existing parameter" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = experiment_id |> Tracking.create_iteration
                parameter_id, _ = Tracking.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                parameter = parameter_id |> Tracking.get_parameter

                @test parameter isa Tracking.Parameter
                @test parameter.id == parameter_id
                @test parameter.iteration_id == iteration_id
                @test parameter.key == "learning_rate"
                @test parameter.value == "0.01"
            end

            @testset "non-existing parameter" begin
                parameter = Tracking.get_parameter(9999)

                @test parameter |> isnothing
            end
        end

        @testset verbose = true "get parameters" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = Tracking.create_iteration(experiment_id)
            Tracking.create_parameter(
                iteration_id,
                "learning_rate",
                0.01,
            )
            Tracking.create_parameter(
                iteration_id,
                "learning_rate_decay",
                "0.001",
            )

            parameters = Tracking.get_parameters(iteration_id)

            @test parameters isa Array{Tracking.Parameter,1}
            @test (parameters |> length) == 2
        end

        @testset verbose = true "update parameter" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = Tracking.create_iteration(experiment_id)
            parameter_id, _ = Tracking.create_parameter(
                iteration_id,
                "learning_rate",
                "0.01",
            )

            parameter = parameter_id |> Tracking.get_parameter

            update_result = Tracking.update_parameter(
                parameter_id,
                nothing,
                0.001,
            )
            @test update_result isa Tracking.Updated

            updated_parameter = parameter_id |> Tracking.get_parameter

            @test updated_parameter.id == parameter_id
            @test updated_parameter.key == "learning_rate"
            @test updated_parameter.value == "0.001"
        end

        @testset verbose = true "delete parameter" begin
            @testset "single parameter" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                parameter_id, _ = Tracking.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                @test parameter_id |> Tracking.delete_parameter
                @test parameter_id |> Tracking.get_parameter |> isnothing
            end

            @testset "all parameters by iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                Tracking.create_parameter(
                    iteration_id,
                    "batch_size",
                    32,
                )
                Tracking.create_parameter(
                    iteration_id,
                    "learning_rate",
                    0.001,
                )
                iteration = iteration_id |> Tracking.get_iteration

                @test Tracking.delete_parameters(iteration)
                @test Tracking.get_parameters(iteration_id) |> isempty
            end
        end
    end
end
