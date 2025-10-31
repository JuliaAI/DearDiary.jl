@with_trackingapi_test_db begin
    @testset verbose = true "parameter service" begin
        @testset verbose = true "create parameter" begin
            @testset "with existing iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)

                parameter_id, result = TrackingAPI.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                @test parameter_id isa Integer
                @test result isa TrackingAPI.Created
            end

            @testset "with non-existing iteration" begin
                parameter_id, result = TrackingAPI.create_parameter(
                    9999,
                    "learning_rate",
                    0.01,
                )

                @test parameter_id |> isnothing
                @test result isa TrackingAPI.Unprocessable
            end
        end

        @testset verbose = true "get parameter by id" begin
            @testset "existing parameter" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                parameter_id, _ = TrackingAPI.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                parameter = TrackingAPI.get_parameter_by_id(parameter_id)

                @test parameter isa TrackingAPI.Parameter
                @test parameter.id == parameter_id
                @test parameter.iteration_id == iteration_id
                @test parameter.key == "learning_rate"
                @test parameter.value == "0.01"
            end

            @testset "non-existing parameter" begin
                parameter = TrackingAPI.get_parameter_by_id(9999)

                @test parameter |> isnothing
            end
        end

        @testset verbose = true "get parameters" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
            TrackingAPI.create_parameter(
                iteration_id,
                "learning_rate",
                0.01,
            )
            TrackingAPI.create_parameter(
                iteration_id,
                "learning_rate_decay",
                "0.001",
            )

            parameters = TrackingAPI.get_parameters(iteration_id)

            @test parameters isa Array{TrackingAPI.Parameter,1}
            @test (parameters |> length) == 2
        end

        @testset verbose = true "update parameter" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Test experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
            parameter_id, _ = TrackingAPI.create_parameter(
                iteration_id,
                "learning_rate",
                "0.01",
            )

            parameter = TrackingAPI.get_parameter_by_id(parameter_id)

            update_result = TrackingAPI.update_parameter(
                parameter_id,
                nothing,
                0.001,
            )
            @test update_result isa TrackingAPI.Updated

            updated_parameter = TrackingAPI.get_parameter_by_id(parameter_id)

            @test updated_parameter.id == parameter_id
            @test updated_parameter.key == "learning_rate"
            @test updated_parameter.value == "0.001"
        end

        @testset verbose = true "delete parameter" begin
            @testset "single parameter" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                parameter_id, _ = TrackingAPI.create_parameter(
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )

                @test TrackingAPI.delete_parameter(parameter_id)
                @test TrackingAPI.get_parameter_by_id(parameter_id) |> isnothing
            end

            @testset "all parameters by iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Test experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                TrackingAPI.create_parameter(
                    iteration_id,
                    "batch_size",
                    32,
                )
                TrackingAPI.create_parameter(
                    iteration_id,
                    "learning_rate",
                    0.001,
                )
                iteration = TrackingAPI.get_iteration_by_id(iteration_id)

                @test TrackingAPI.delete_parameters(iteration)
                @test TrackingAPI.get_parameters(iteration_id) |> isempty
            end
        end
    end
end
