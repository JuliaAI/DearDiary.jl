@with_deardiary_test_db begin
    @testset verbose = true "model version service" begin
        function _scaffold(; project_name::AbstractString="ModelVersion Service Project")
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, project_name)
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            model_id, _ = DearDiary.create_model(project_id, "fraud-classifier")
            return (project_id, experiment_id, iteration_id, model_id)
        end

        @testset verbose = true "create model version" begin
            @testset "valid registration assigns version 1" begin
                _, _, iteration_id, model_id = _scaffold()

                version_id, result = DearDiary.create_modelversion(
                    model_id, iteration_id, nothing, ""
                )

                @test version_id isa String
                @test !isempty(version_id)
                @test result === DearDiary.Created

                version = DearDiary.get_modelversion(version_id)
                @test version.version == 1
                @test version.stage_id == (Integer(DearDiary.NO_STAGE))
                @test isnothing(version.resource_id)
            end

            @testset "subsequent registration increments version" begin
                _, _, iteration_id, model_id = _scaffold()
                DearDiary.create_modelversion(model_id, iteration_id, nothing, "")

                version_id, _ = DearDiary.create_modelversion(
                    model_id, iteration_id, nothing, ""
                )
                version = DearDiary.get_modelversion(version_id)
                @test version.version == 2
            end

            @testset "non-existing model" begin
                _, _, iteration_id, _ = _scaffold()

                version_id, result = DearDiary.create_modelversion(
                    "00000000-0000-0000-0000-000000000000", iteration_id, nothing, ""
                )
                @test isnothing(version_id)
                @test result === DearDiary.Unprocessable
            end

            @testset "non-existing iteration" begin
                _, _, _, model_id = _scaffold()

                version_id, result = DearDiary.create_modelversion(
                    model_id, "00000000-0000-0000-0000-000000000000", nothing, ""
                )
                @test isnothing(version_id)
                @test result === DearDiary.Unprocessable
            end

            @testset "iteration belongs to a different project" begin
                _, _, _, model_id = _scaffold()
                _, _, other_iteration_id, _ = _scaffold(; project_name="Other Project")

                version_id, result = DearDiary.create_modelversion(
                    model_id, other_iteration_id, nothing, ""
                )
                @test isnothing(version_id)
                @test result === DearDiary.Unprocessable
            end

            @testset "resource belongs to a different project" begin
                _, _, iteration_id, model_id = _scaffold()
                # Create a resource under a sibling project.
                user = DearDiary.get_user_by_username("default")
                other_project_id, _ = DearDiary.create_project(user.id, "Other Project 2")
                other_experiment_id, _ = DearDiary.create_experiment(
                    other_project_id, DearDiary.IN_PROGRESS, "Other Exp"
                )
                resource_id, _ = DearDiary.create_resource(
                    other_experiment_id, "model.bin", UInt8[0x00, 0x01]
                )

                version_id, result = DearDiary.create_modelversion(
                    model_id, iteration_id, resource_id, ""
                )
                @test isnothing(version_id)
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "update model version" begin
            @testset "valid stage promotion" begin
                _, _, iteration_id, model_id = _scaffold()
                version_id, _ = DearDiary.create_modelversion(
                    model_id, iteration_id, nothing, ""
                )

                result = DearDiary.update_modelversion(
                    version_id, DearDiary.STAGING, nothing, nothing
                )
                @test result === DearDiary.Updated

                version = DearDiary.get_modelversion(version_id)
                @test version.stage_id == (Integer(DearDiary.STAGING))
            end

            @testset "promotion to PRODUCTION archives siblings" begin
                _, _, iteration_id, model_id = _scaffold()
                old_id, _ = DearDiary.create_modelversion(
                    model_id, iteration_id, nothing, ""
                )
                new_id, _ = DearDiary.create_modelversion(
                    model_id, iteration_id, nothing, ""
                )
                # Put the older version in PRODUCTION first.
                DearDiary.update_modelversion(
                    old_id, DearDiary.PRODUCTION, nothing, nothing
                )

                # Promote the newer one; the older sibling should be auto-archived.
                result = DearDiary.update_modelversion(
                    new_id, DearDiary.PRODUCTION, nothing, nothing
                )
                @test result === DearDiary.Updated

                old_version = DearDiary.get_modelversion(old_id)
                new_version = DearDiary.get_modelversion(new_id)
                @test old_version.stage_id == (Integer(DearDiary.ARCHIVED))
                @test new_version.stage_id == (Integer(DearDiary.PRODUCTION))
            end

            @testset "invalid stage_id" begin
                _, _, iteration_id, model_id = _scaffold()
                version_id, _ = DearDiary.create_modelversion(
                    model_id, iteration_id, nothing, ""
                )

                result = DearDiary.update_modelversion(version_id, 9999, nothing, nothing)
                @test result === DearDiary.Unprocessable
            end

            @testset "non-existing id" begin
                result = DearDiary.update_modelversion(
                    "00000000-0000-0000-0000-000000000000",
                    DearDiary.STAGING,
                    nothing,
                    nothing,
                )
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "delete model version does not touch resource" begin
            _, experiment_id, iteration_id, model_id = _scaffold()
            resource_id, _ = DearDiary.create_resource(
                experiment_id, "model.bin", UInt8[0x00, 0x01]
            )
            version_id, _ = DearDiary.create_modelversion(
                model_id, iteration_id, resource_id, ""
            )

            @test DearDiary.delete_modelversion(version_id)
            @test isnothing(DearDiary.get_modelversion(version_id))
            @test DearDiary.get_resource(resource_id) isa DearDiary.Resource
        end

        @testset verbose = true "get project id" begin
            project_id, _, iteration_id, model_id = _scaffold()
            version_id, _ = DearDiary.create_modelversion(
                model_id, iteration_id, nothing, ""
            )

            version = DearDiary.get_modelversion(version_id)
            @test (DearDiary.get_project_id(version)) == project_id
        end
    end
end
