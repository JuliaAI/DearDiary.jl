@with_deardiary_test_db begin
    @testset verbose = true "parameter repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)

                id, status = DearDiary.insert(
                    DearDiary.Parameter,
                    iteration_id,
                    "learning_rate",
                    "0.01",
                )
                @test id isa Integer
                @test status isa DearDiary.Created
            end

            @testset "with non-existing iteration" begin
                id, status = DearDiary.insert(
                    DearDiary.Parameter,
                    9999,
                    "learning_rate",
                    "0.01",
                )
                @test id |> isnothing
                @test status isa DearDiary.Unprocessable
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing parameter" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                parameter_id, _ = DearDiary.insert(
                    DearDiary.Parameter,
                    iteration_id,
                    "batch_size",
                    "32",
                )

                parameter = DearDiary.fetch(DearDiary.Parameter, parameter_id)

                @test parameter isa DearDiary.Parameter
                @test parameter.id == parameter_id
                @test parameter.iteration_id == iteration_id
                @test parameter.key == "batch_size"
                @test parameter.value == "32"
            end

            @testset "non-existing parameter" begin
                parameter = DearDiary.fetch(DearDiary.Parameter, 9999)

                @test parameter |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Parameter Test Experiment",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.insert(
                DearDiary.Parameter,
                iteration_id,
                "dropout_rate",
                "0.5",
            )
            DearDiary.insert(
                DearDiary.Parameter,
                iteration_id,
                "momentum",
                "0.9",
            )
            parameters = DearDiary.fetch_all(DearDiary.Parameter, iteration_id)

            @test parameters isa Array{DearDiary.Parameter,1}
            @test (parameters |> length) == 2
        end

        @testset verbose = true "update" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Parameter Test Experiment",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            parameter_id, _ = DearDiary.insert(
                DearDiary.Parameter,
                iteration_id,
                "weight_decay",
                "0.0001",
            )

            update_result = DearDiary.update(
                DearDiary.Parameter,
                parameter_id;
                value="0.0005",
            )

            @test update_result isa DearDiary.Updated

            parameter = DearDiary.fetch(DearDiary.Parameter, parameter_id)
            @test parameter.value == "0.0005"
        end

        @testset verbose = true "delete" begin
            @testset "single parameter" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                parameter_id, _ = DearDiary.insert(
                    DearDiary.Parameter,
                    iteration_id,
                    "activation_function",
                    "relu",
                )

                @test DearDiary.delete(DearDiary.Parameter, parameter_id)
                @test DearDiary.fetch(DearDiary.Parameter, parameter_id) |> isnothing
            end

            @testset "all parameters by iteration" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Parameter Test Experiment",
                )
                iteration_id, _ = DearDiary.create_iteration(experiment_id)
                iteration = iteration_id |> DearDiary.get_iteration
                DearDiary.insert(
                    DearDiary.Parameter,
                    iteration_id,
                    "optimizer",
                    "adam",
                )
                DearDiary.insert(
                    DearDiary.Parameter,
                    iteration_id,
                    "loss_function",
                    "cross_entropy",
                )

                @test DearDiary.delete(DearDiary.Parameter, iteration)

                parameters = DearDiary.fetch_all(DearDiary.Parameter, iteration_id)
                @test parameters |> isempty
            end
        end
    end
end
