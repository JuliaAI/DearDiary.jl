@with_deardiary_test_db begin
    @testset verbose = true "model repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing project" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Model Project")

                id, status = DearDiary.insert(
                    DearDiary.Model, project_id, "fraud-classifier",
                )
                @test id isa Integer
                @test status === DearDiary.Created
            end

            @testset "with duplicate name in project" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Model Project")
                DearDiary.insert(DearDiary.Model, project_id, "fraud-classifier")

                id, status = DearDiary.insert(
                    DearDiary.Model, project_id, "fraud-classifier",
                )
                @test id |> isnothing
                @test status === DearDiary.Duplicate
            end

            @testset "with non-existing project" begin
                id, status = DearDiary.insert(
                    DearDiary.Model, 9999, "orphan-classifier",
                )
                @test id |> isnothing
                @test status === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing model" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Model Project")
                model_id, _ = DearDiary.insert(
                    DearDiary.Model, project_id, "fraud-classifier",
                )

                model = DearDiary.fetch(DearDiary.Model, model_id)

                @test model isa DearDiary.Model
                @test model.id == model_id
                @test model.project_id == project_id
                @test model.name == "fraud-classifier"
                @test model.created_date isa DateTime
            end

            @testset "non-existing model" begin
                @test DearDiary.fetch(DearDiary.Model, 9999) |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Model Project")
            DearDiary.insert(DearDiary.Model, project_id, "m1")
            DearDiary.insert(DearDiary.Model, project_id, "m2")

            models = DearDiary.fetch_all(DearDiary.Model, project_id)

            @test models isa Array{DearDiary.Model,1}
            @test (models |> length) == 2
        end

        @testset verbose = true "update" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Model Project")
            model_id, _ = DearDiary.insert(
                DearDiary.Model, project_id, "fraud-classifier",
            )

            update_result = DearDiary.update(
                DearDiary.Model, model_id;
                description="Production fraud-detection classifier",
            )

            @test update_result === DearDiary.Updated

            model = DearDiary.fetch(DearDiary.Model, model_id)
            @test model.description == "Production fraud-detection classifier"
            @test model.updated_date isa DateTime
        end

        @testset verbose = true "delete" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Model Project")
            model_id, _ = DearDiary.insert(
                DearDiary.Model, project_id, "fraud-classifier",
            )

            @test DearDiary.delete(DearDiary.Model, model_id)
            @test DearDiary.fetch(DearDiary.Model, model_id) |> isnothing
        end
    end
end
