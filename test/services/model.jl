@with_deardiary_test_db begin
    @testset verbose = true "model service" begin
        @testset verbose = true "create model" begin
            @testset "with existing project" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Service Model Project")

                model_id, result = DearDiary.create_model(project_id, "fraud-classifier")

                @test model_id isa Integer
                @test result === DearDiary.Created
            end

            @testset "with non-existing project" begin
                model_id, result = DearDiary.create_model(9999, "orphan-model")

                @test model_id |> isnothing
                @test result === DearDiary.Unprocessable
            end

            @testset "duplicate name within project" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Service Model Project")
                DearDiary.create_model(project_id, "fraud-classifier")

                model_id, result = DearDiary.create_model(project_id, "fraud-classifier")

                @test model_id |> isnothing
                @test result === DearDiary.Duplicate
            end
        end

        @testset verbose = true "get model" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Service Model Project")
            model_id, _ = DearDiary.create_model(project_id, "fraud-classifier")

            model = model_id |> DearDiary.get_model

            @test model isa DearDiary.Model
            @test model.id == model_id
            @test model.project_id == project_id
            @test model.name == "fraud-classifier"

            @test DearDiary.get_model(9999) |> isnothing
        end

        @testset verbose = true "get models" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Service Model Project")
            DearDiary.create_model(project_id, "m1")
            DearDiary.create_model(project_id, "m2")

            models = DearDiary.get_models(project_id)

            @test models isa Array{DearDiary.Model,1}
            @test (models |> length) == 2
        end

        @testset verbose = true "get models paginated" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Pagination Model Project")
            for i in 1:5
                DearDiary.create_model(project_id, "model-$(i)")
            end

            page = DearDiary.get_models(project_id, DearDiary.Pagination(2, 0))

            @test page isa DearDiary.PaginatedResponse{DearDiary.Model}
            @test (page.data |> length) == 2
            @test page.total == 5
        end

        @testset verbose = true "update model" begin
            @testset "with existing id" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Service Model Project")
                model_id, _ = DearDiary.create_model(project_id, "fraud-classifier")

                result = DearDiary.update_model(
                    model_id, "fraud-classifier-v2", "Updated description",
                )
                @test result === DearDiary.Updated

                model = model_id |> DearDiary.get_model
                @test model.name == "fraud-classifier-v2"
                @test model.description == "Updated description"
            end

            @testset "with non-existing id" begin
                result = DearDiary.update_model(9999, "x", "y")
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "delete model cascades versions" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Service Model Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Exp",
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            model_id, _ = DearDiary.create_model(project_id, "fraud-classifier")
            DearDiary.create_modelversion(model_id, iteration_id, nothing, "v1")
            DearDiary.create_modelversion(model_id, iteration_id, nothing, "v2")

            @test DearDiary.delete_model(model_id)
            @test DearDiary.get_model(model_id) |> isnothing
            @test DearDiary.get_modelversions(model_id) |> isempty
        end

        @testset verbose = true "get project id" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Service Model Project")
            model_id, _ = DearDiary.create_model(project_id, "fraud-classifier")

            model = model_id |> DearDiary.get_model
            @test (model |> DearDiary.get_project_id) == project_id
        end
    end
end
