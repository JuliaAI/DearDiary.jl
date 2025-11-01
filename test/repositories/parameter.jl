@with_tracking_test_db begin
    @testset verbose = true "parameter repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)

                @test Tracking.insert(
                    Tracking.Parameter,
                    iteration_id,
                    "learning_rate",
                    "0.01",
                ) isa Tuple{Integer,Tracking.Created}
            end

            @testset "with non-existing iteration" begin
                @test Tracking.insert(
                    Tracking.Parameter,
                    9999,
                    "learning_rate",
                    "0.01",
                ) isa Tuple{Nothing,Tracking.Unprocessable}
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing parameter" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                parameter_id, _ = Tracking.insert(
                    Tracking.Parameter,
                    iteration_id,
                    "batch_size",
                    "32",
                )

                parameter = Tracking.fetch(Tracking.Parameter, parameter_id)

                @test parameter isa Tracking.Parameter
                @test parameter.id == parameter_id
                @test parameter.iteration_id == iteration_id
                @test parameter.key == "batch_size"
                @test parameter.value == "32"
            end

            @testset "non-existing parameter" begin
                parameter = Tracking.fetch(Tracking.Parameter, 9999)

                @test parameter |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Parameter Test Experiment",
            )
            iteration_id, _ = Tracking.create_iteration(experiment_id)
            Tracking.insert(
                Tracking.Parameter,
                iteration_id,
                "dropout_rate",
                "0.5",
            )
            Tracking.insert(
                Tracking.Parameter,
                iteration_id,
                "momentum",
                "0.9",
            )
            parameters = Tracking.fetch_all(Tracking.Parameter, iteration_id)

            @test parameters isa Array{Tracking.Parameter,1}
            @test (parameters |> length) == 2
        end

        @testset verbose = true "update" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Parameter Test Experiment",
            )
            iteration_id, _ = Tracking.create_iteration(experiment_id)
            parameter_id, _ = Tracking.insert(
                Tracking.Parameter,
                iteration_id,
                "weight_decay",
                "0.0001",
            )

            update_result = Tracking.update(
                Tracking.Parameter,
                parameter_id;
                value="0.0005",
            )

            @test update_result isa Tracking.Updated

            parameter = Tracking.fetch(Tracking.Parameter, parameter_id)
            @test parameter.value == "0.0005"
        end

        @testset verbose = true "delete" begin
            @testset "single parameter" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                parameter_id, _ = Tracking.insert(
                    Tracking.Parameter,
                    iteration_id,
                    "activation_function",
                    "relu",
                )

                @test Tracking.delete(Tracking.Parameter, parameter_id)
                @test Tracking.fetch(Tracking.Parameter, parameter_id) |> isnothing
            end

            @testset "all parameters by iteration" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = Tracking.create_iteration(experiment_id)
                iteration = iteration_id |> Tracking.get_iteration
                Tracking.insert(
                    Tracking.Parameter,
                    iteration_id,
                    "optimizer",
                    "adam",
                )
                Tracking.insert(
                    Tracking.Parameter,
                    iteration_id,
                    "loss_function",
                    "cross_entropy",
                )

                @test Tracking.delete(Tracking.Parameter, iteration)

                parameters = Tracking.fetch_all(Tracking.Parameter, iteration_id)
                @test parameters |> isempty
            end
        end
    end
end
