@with_tracking_test_db begin
    @testset verbose = true "resource repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing experiment" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test Experiment",
                )

                @test Tracking.insert(
                    Tracking.Resource,
                    experiment_id,
                    "Test Resource",
                    UInt8[0x01, 0x02, 0x03, 0x04],
                ) isa Tuple{Integer,Tracking.Created}
            end

            @testset "with non-existing experiment" begin
                @test Tracking.insert(
                    Tracking.Resource,
                    9999,
                    "Test Resource",
                    UInt8[0x01, 0x02, 0x03, 0x04],
                ) isa Tuple{Nothing,Tracking.Unprocessable}
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing resource" begin
                user = Tracking.get_user("default")
                project_id, _ = Tracking.create_project(user.id, "Test Project")
                experiment_id, _ = Tracking.create_experiment(
                    project_id,
                    Tracking.IN_PROGRESS,
                    "Test Experiment",
                )
                resource_data = UInt8[0x0A, 0x0B, 0x0C]

                resource_id, _ = Tracking.insert(
                    Tracking.Resource,
                    experiment_id,
                    "Test Resource",
                    resource_data,
                )

                resource = Tracking.fetch(Tracking.Resource, resource_id)

                @test resource isa Tracking.Resource
                @test resource.id == resource_id
                @test resource.experiment_id == experiment_id
                @test resource.name == "Test Resource"
                @test resource.data == resource_data
                @test resource.created_date isa DateTime
            end

            @testset "non-existing resource" begin
                resource = Tracking.fetch(Tracking.Resource, 9999)

                @test resource |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test Experiment",
            )

            Tracking.insert(
                Tracking.Resource,
                experiment_id,
                "Test Resource",
                UInt8[0x01, 0x02, 0x03, 0x04],
            )
            Tracking.insert(
                Tracking.Resource,
                experiment_id,
                "Test Resource",
                UInt8[0x05, 0x06, 0x07, 0x08],
            )
            resources = Tracking.fetch_all(Tracking.Resource, experiment_id)

            @test resources isa Array{Tracking.Resource,1}
            @test (resources |> length) == 2
            @test all(resource -> resource.data |> isnothing, resources)
        end

        @testset verbose = true "update" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test Experiment",
            )

            resource_id, _ = Tracking.insert(
                Tracking.Resource,
                experiment_id,
                "Test Resource",
                UInt8[0x0A, 0x0B, 0x0C],
            )

            update_result = Tracking.update(
                Tracking.Resource,
                resource_id;
                name="Updated Resource",
                description="This is an updated resource.",
                data=UInt8[0x0D, 0x0E, 0x0F],
            )

            @test update_result isa Tracking.Updated

            resource = Tracking.fetch(Tracking.Resource, resource_id)
            @test resource.name == "Updated Resource"
            @test resource.description == "This is an updated resource."
            @test resource.data == UInt8[0x0D, 0x0E, 0x0F]
            @test resource.updated_date isa DateTime
        end

        @testset verbose = true "delete" begin
            user = Tracking.get_user("default")
            project_id, _ = Tracking.create_project(user.id, "Test Project")
            experiment_id, _ = Tracking.create_experiment(
                project_id,
                Tracking.IN_PROGRESS,
                "Test Experiment",
            )

            resource_id, _ = Tracking.insert(
                Tracking.Resource,
                experiment_id,
                "Test Resource",
                UInt8[0x0A, 0x0B, 0x0C],
            )

            @test Tracking.delete(Tracking.Resource, resource_id)
            @test Tracking.fetch(Tracking.Resource, resource_id) |> isnothing
        end
    end
end
