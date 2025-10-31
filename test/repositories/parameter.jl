@with_trackingapi_test_db begin
    @testset verbose = true "parameter repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)

                @test TrackingAPI.insert(
                    TrackingAPI.Parameter,
                    iteration_id,
                    "learning_rate",
                    "0.01",
                ) isa Tuple{Integer,TrackingAPI.Created}
            end

            @testset "with non-existing iteration" begin
                @test TrackingAPI.insert(
                    TrackingAPI.Parameter,
                    9999,
                    "learning_rate",
                    "0.01",
                ) isa Tuple{Nothing,TrackingAPI.Unprocessable}
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing parameter" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                parameter_id, _ = TrackingAPI.insert(
                    TrackingAPI.Parameter,
                    iteration_id,
                    "batch_size",
                    "32",
                )

                parameter = TrackingAPI.fetch(TrackingAPI.Parameter, parameter_id)

                @test parameter isa TrackingAPI.Parameter
                @test parameter.id == parameter_id
                @test parameter.iteration_id == iteration_id
                @test parameter.key == "batch_size"
                @test parameter.value == "32"
            end

            @testset "non-existing parameter" begin
                parameter = TrackingAPI.fetch(TrackingAPI.Parameter, 9999)

                @test parameter |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Parameter Test Experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
            TrackingAPI.insert(
                TrackingAPI.Parameter,
                iteration_id,
                "dropout_rate",
                "0.5",
            )
            TrackingAPI.insert(
                TrackingAPI.Parameter,
                iteration_id,
                "momentum",
                "0.9",
            )
            parameters = TrackingAPI.fetch_all(TrackingAPI.Parameter, iteration_id)

            @test parameters isa Array{TrackingAPI.Parameter,1}
            @test (parameters |> length) == 2
        end

        @testset verbose = true "update" begin
            user = TrackingAPI.get_user_by_username("default")
            project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
            experiment_id, _ = TrackingAPI.create_experiment(
                project_id,
                TrackingAPI.IN_PROGRESS,
                "Parameter Test Experiment",
            )
            iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
            parameter_id, _ = TrackingAPI.insert(
                TrackingAPI.Parameter,
                iteration_id,
                "weight_decay",
                "0.0001",
            )

            update_result = TrackingAPI.update(
                TrackingAPI.Parameter,
                parameter_id;
                value="0.0005",
            )

            @test update_result isa TrackingAPI.Updated

            parameter = TrackingAPI.fetch(TrackingAPI.Parameter, parameter_id)
            @test parameter.value == "0.0005"
        end

        @testset verbose = true "delete" begin
            @testset "single parameter" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                parameter_id, _ = TrackingAPI.insert(
                    TrackingAPI.Parameter,
                    iteration_id,
                    "activation_function",
                    "relu",
                )

                @test TrackingAPI.delete(TrackingAPI.Parameter, parameter_id)
                @test TrackingAPI.fetch(TrackingAPI.Parameter, parameter_id) |> isnothing
            end

            @testset "all parameters by iteration" begin
                user = TrackingAPI.get_user_by_username("default")
                project_id, _ = TrackingAPI.create_project(user.id, "Test Project")
                experiment_id, _ = TrackingAPI.create_experiment(
                    project_id,
                    TrackingAPI.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = TrackingAPI.create_iteration(experiment_id)
                iteration = TrackingAPI.get_iteration_by_id(iteration_id)
                TrackingAPI.insert(
                    TrackingAPI.Parameter,
                    iteration_id,
                    "optimizer",
                    "adam",
                )
                TrackingAPI.insert(
                    TrackingAPI.Parameter,
                    iteration_id,
                    "loss_function",
                    "cross_entropy",
                )

                @test TrackingAPI.delete(TrackingAPI.Parameter, iteration)

                parameters = TrackingAPI.fetch_all(TrackingAPI.Parameter, iteration_id)
                @test parameters |> isempty
            end
        end
    end
end
