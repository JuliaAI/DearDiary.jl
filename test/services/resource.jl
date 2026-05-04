@with_deardiary_test_db begin
    @testset verbose = true "resource service" begin
        @testset verbose = true "create resource" begin
            @testset "with existing experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test Experiment",
                )

                resource_id, result = DearDiary.create_resource(
                    experiment_id,
                    "Test Resource",
                    UInt8[0x01, 0x02, 0x03, 0x04],
                )

                @test resource_id isa Integer
                @test result === DearDiary.Created
            end

            @testset "with non-existing experiment" begin
                resource_id, result = DearDiary.create_resource(
                    9999,
                    "Test Resource",
                    UInt8[0x01, 0x02, 0x03, 0x04],
                )

                @test resource_id |> isnothing
                @test result === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "get resource by id" begin
            @testset "existing resource" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test Experiment",
                )
                resource_data = UInt8[0x0A, 0x0B, 0x0C]
                resource_id, _ = DearDiary.create_resource(
                    experiment_id,
                    "Test Resource",
                    resource_data,
                )

                resource = resource_id |> DearDiary.get_resource

                @test resource isa DearDiary.Resource
                @test resource.id == resource_id
                @test resource.experiment_id == experiment_id
                @test resource.name == "Test Resource"
                @test resource.data == resource_data
            end

            @testset "non-existing resource" begin
                resource = DearDiary.get_resource(9999)

                @test resource |> isnothing
            end
        end

        @testset verbose = true "get resources" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test Experiment",
            )
            DearDiary.create_resource(
                experiment_id,
                "Test Resource 1",
                UInt8[0x01, 0x02, 0x03, 0x04],
            )
            DearDiary.create_resource(
                experiment_id,
                "Test Resource 2",
                UInt8[0x05, 0x06, 0x07, 0x08],
            )

            resources = DearDiary.get_resources(experiment_id)

            @test resources isa Array{DearDiary.Resource,1}
            @test (resources |> length) == 2
        end

        @testset verbose = true "update resource" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_resource(
                    9999,
                    "Updated Resource",
                    "This is an updated resource.",
                    UInt8[0x0D, 0x0E, 0x0F],
                )

                @test result === DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test Experiment",
                )
                resource_id, _ = DearDiary.create_resource(
                    experiment_id,
                    "Test Resource",
                    UInt8[0x0A, 0x0B, 0x0C],
                )

                resource = resource_id |> DearDiary.get_resource

                update_result = DearDiary.update_resource(
                    resource_id,
                    "Updated Resource",
                    "This is an updated resource.",
                    UInt8[0x0D, 0x0E, 0x0F],
                )
                @test update_result === DearDiary.Updated

                updated_resource = resource_id |> DearDiary.get_resource

                @test updated_resource.id == resource_id
                @test updated_resource.name == "Updated Resource"
                @test updated_resource.description == "This is an updated resource."
                @test updated_resource.data == UInt8[0x0D, 0x0E, 0x0F]
            end
        end

        @testset verbose = true "delete resource" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test Experiment",
            )
            resource_id, _ = DearDiary.create_resource(
                experiment_id,
                "Test Resource",
                UInt8[0x0A, 0x0B, 0x0C],
            )

            @test resource_id |> DearDiary.delete_resource
            @test (resource_id |> DearDiary.get_resource) |> isnothing
        end

        @testset verbose = true "get project id" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test Experiment",
            )
            resource_id, _ = DearDiary.create_resource(
                experiment_id,
                "Test Resource",
                UInt8[0x01, 0x02, 0x03, 0x04],
            )

            @testset "with existing parent experiment" begin
                resource = resource_id |> DearDiary.get_resource
                @test (resource |> DearDiary.get_project_id) == project_id
            end

            @testset "with deleted parent experiment" begin
                resource = resource_id |> DearDiary.get_resource
                DearDiary.delete_experiment(experiment_id)
                @test (resource |> DearDiary.get_project_id) |> isnothing
            end
        end
    end
end
