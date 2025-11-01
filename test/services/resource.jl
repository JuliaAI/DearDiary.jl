@with_tracking_test_db begin
    @testset verbose = true "resource service" begin
        @testset verbose = true "create resource" begin
            @testset "with existing experiment" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test Experiment",
                )

                resource_id, result = Tracking.create_resource(
                    experiment_id,
                    "Test Resource",
                    UInt8[0x01, 0x02, 0x03, 0x04],
                )

                @test resource_id isa Integer
                @test result isa Tracking.Created
            end

            @testset "with non-existing experiment" begin
                resource_id, result = Tracking.create_resource(
                    9999,
                    "Test Resource",
                    UInt8[0x01, 0x02, 0x03, 0x04],
                )

                @test resource_id |> isnothing
                @test result isa Tracking.Unprocessable
            end
        end

        @testset verbose = true "get resource by id" begin
            @testset "existing resource" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test Experiment",
                )
                resource_data = UInt8[0x0A, 0x0B, 0x0C]
                resource_id, _ = Tracking.create_resource(
                    experiment_id,
                    "Test Resource",
                    resource_data,
                )

                resource = resource_id |> Tracking.get_resource

                @test resource isa Tracking.Resource
                @test resource.id == resource_id
                @test resource.experiment_id == experiment_id
                @test resource.name == "Test Resource"
                @test resource.data == resource_data
            end

            @testset "non-existing resource" begin
                resource = Tracking.get_resource(9999)

                @test resource |> isnothing
            end
        end

        @testset verbose = true "get resources" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test Experiment",
            )
            Tracking.create_resource(
                experiment_id,
                "Test Resource 1",
                UInt8[0x01, 0x02, 0x03, 0x04],
            )
            Tracking.create_resource(
                experiment_id,
                "Test Resource 2",
                UInt8[0x05, 0x06, 0x07, 0x08],
            )

            resources = Tracking.get_resources(experiment_id)

            @test resources isa Array{Tracking.Resource,1}
            @test (resources |> length) == 2
        end

        @testset verbose = true "update resource" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test Experiment",
            )
            resource_id, _ = Tracking.create_resource(
                experiment_id,
                "Test Resource",
                UInt8[0x0A, 0x0B, 0x0C],
            )

            resource = resource_id |> Tracking.get_resource

            update_result = Tracking.update_resource(
                resource_id,
                "Updated Resource",
                "This is an updated resource.",
                UInt8[0x0D, 0x0E, 0x0F],
            )
            @test update_result isa Tracking.Updated

            updated_resource = resource_id |> Tracking.get_resource

            @test updated_resource.id == resource_id
            @test updated_resource.name == "Updated Resource"
            @test updated_resource.description == "This is an updated resource."
            @test updated_resource.data == UInt8[0x0D, 0x0E, 0x0F]
        end

        @testset verbose = true "delete resource" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test Experiment",
            )
            resource_id, _ = Tracking.create_resource(
                experiment_id,
                "Test Resource",
                UInt8[0x0A, 0x0B, 0x0C],
            )

            @test resource_id |> Tracking.delete_resource
            @test (resource_id |> Tracking.get_resource) |> isnothing
        end
    end
end
