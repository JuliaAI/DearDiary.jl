@with_deardiary_test_db begin
    @testset verbose = true "resource service" begin
        @testset verbose = true "create resource" begin
            @testset "with existing experiment" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test Experiment"
                )

                resource_id, result = DearDiary.create_resource(
                    experiment_id, "Test Resource", UInt8[0x01, 0x02, 0x03, 0x04]
                )

                @test resource_id isa String
                @test !isempty(resource_id)
                @test result === DearDiary.Created
            end

            @testset "with non-existing experiment" begin
                resource_id, result = DearDiary.create_resource(
                    "00000000-0000-0000-0000-000000000000",
                    "Test Resource",
                    UInt8[0x01, 0x02, 0x03, 0x04],
                )

                @test isnothing(resource_id)
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "get resource by id" begin
            @testset "existing resource" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test Experiment"
                )
                resource_data = UInt8[0x0A, 0x0B, 0x0C]
                resource_id, _ = DearDiary.create_resource(
                    experiment_id, "Test Resource", resource_data
                )

                resource = DearDiary.get_resource(resource_id)

                @test resource isa DearDiary.Resource
                @test resource.id == resource_id
                @test resource.experiment_id == experiment_id
                @test resource.name == "Test Resource"
                @test resource.data == resource_data
            end

            @testset "non-existing resource" begin
                resource = DearDiary.get_resource("00000000-0000-0000-0000-000000000000")

                @test isnothing(resource)
            end
        end

        @testset verbose = true "get resources" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Test Experiment"
            )
            DearDiary.create_resource(
                experiment_id, "Test Resource 1", UInt8[0x01, 0x02, 0x03, 0x04]
            )
            DearDiary.create_resource(
                experiment_id, "Test Resource 2", UInt8[0x05, 0x06, 0x07, 0x08]
            )

            resources = DearDiary.get_resources(experiment_id)

            @test resources isa Array{DearDiary.Resource,1}
            @test (length(resources)) == 2
        end

        @testset verbose = true "update resource" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_resource(
                    "00000000-0000-0000-0000-000000000000",
                    "Updated Resource",
                    "This is an updated resource.",
                    UInt8[0x0D, 0x0E, 0x0F],
                )

                @test result === DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Test Experiment"
                )
                resource_id, _ = DearDiary.create_resource(
                    experiment_id, "Test Resource", UInt8[0x0A, 0x0B, 0x0C]
                )

                resource = DearDiary.get_resource(resource_id)

                update_result = DearDiary.update_resource(
                    resource_id,
                    "Updated Resource",
                    "This is an updated resource.",
                    UInt8[0x0D, 0x0E, 0x0F],
                )
                @test update_result === DearDiary.Updated

                updated_resource = DearDiary.get_resource(resource_id)

                @test updated_resource.id == resource_id
                @test updated_resource.name == "Updated Resource"
                @test updated_resource.description == "This is an updated resource."
                @test updated_resource.data == UInt8[0x0D, 0x0E, 0x0F]
            end
        end

        @testset verbose = true "delete resource" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Test Experiment"
            )
            resource_id, _ = DearDiary.create_resource(
                experiment_id, "Test Resource", UInt8[0x0A, 0x0B, 0x0C]
            )

            @test DearDiary.delete_resource(resource_id)
            @test isnothing((DearDiary.get_resource(resource_id)))
        end

        @testset verbose = true "get project id" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Test Experiment"
            )
            resource_id, _ = DearDiary.create_resource(
                experiment_id, "Test Resource", UInt8[0x01, 0x02, 0x03, 0x04]
            )

            @testset "with existing parent experiment" begin
                resource = DearDiary.get_resource(resource_id)
                @test (DearDiary.get_project_id(resource)) == project_id
            end

            @testset "with deleted parent experiment" begin
                resource = DearDiary.get_resource(resource_id)
                DearDiary.delete_experiment(experiment_id)
                @test isnothing((DearDiary.get_project_id(resource)))
            end
        end
    end
end
