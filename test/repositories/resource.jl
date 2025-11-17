@with_deardiary_test_db begin
    @testset verbose = true "resource repository" begin
        @testset verbose = true "insert" begin
            @testset "with existing experiment" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test Experiment",
                )

                id, status = DearDiary.insert(
                    DearDiary.Resource,
                    experiment_id,
                    "Test Resource",
                    UInt8[0x01, 0x02, 0x03, 0x04],
                )
                @test id isa Integer
                @test status isa DearDiary.Created
            end

            @testset "with non-existing experiment" begin
                id, status = DearDiary.insert(
                    DearDiary.Resource,
                    9999,
                    "Test Resource",
                    UInt8[0x01, 0x02, 0x03, 0x04],
                )
                @test id |> isnothing
                @test status isa DearDiary.Unprocessable
            end
        end

        @testset verbose = true "fetch" begin
            @testset "existing resource" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id,
                    DearDiary.IN_PROGRESS,
                    "Test Experiment",
                )
                resource_data = UInt8[0x0A, 0x0B, 0x0C]

                resource_id, _ = DearDiary.insert(
                    DearDiary.Resource,
                    experiment_id,
                    "Test Resource",
                    resource_data,
                )

                resource = DearDiary.fetch(DearDiary.Resource, resource_id)

                @test resource isa DearDiary.Resource
                @test resource.id == resource_id
                @test resource.experiment_id == experiment_id
                @test resource.name == "Test Resource"
                @test resource.data == resource_data
                @test resource.created_date isa DateTime
            end

            @testset "non-existing resource" begin
                resource = DearDiary.fetch(DearDiary.Resource, 9999)

                @test resource |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test Experiment",
            )

            DearDiary.insert(
                DearDiary.Resource,
                experiment_id,
                "Test Resource",
                UInt8[0x01, 0x02, 0x03, 0x04],
            )
            DearDiary.insert(
                DearDiary.Resource,
                experiment_id,
                "Test Resource",
                UInt8[0x05, 0x06, 0x07, 0x08],
            )
            resources = DearDiary.fetch_all(DearDiary.Resource, experiment_id)

            @test resources isa Array{DearDiary.Resource,1}
            @test (resources |> length) == 2
            @test all(resource -> resource.data |> isnothing, resources)
        end

        @testset verbose = true "update" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test Experiment",
            )

            resource_id, _ = DearDiary.insert(
                DearDiary.Resource,
                experiment_id,
                "Test Resource",
                UInt8[0x0A, 0x0B, 0x0C],
            )

            update_result = DearDiary.update(
                DearDiary.Resource,
                resource_id;
                name="Updated Resource",
                description="This is an updated resource.",
                data=UInt8[0x0D, 0x0E, 0x0F],
            )

            @test update_result isa DearDiary.Updated

            resource = DearDiary.fetch(DearDiary.Resource, resource_id)
            @test resource.name == "Updated Resource"
            @test resource.description == "This is an updated resource."
            @test resource.data == UInt8[0x0D, 0x0E, 0x0F]
            @test resource.updated_date isa DateTime
        end

        @testset verbose = true "delete" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id,
                DearDiary.IN_PROGRESS,
                "Test Experiment",
            )

            resource_id, _ = DearDiary.insert(
                DearDiary.Resource,
                experiment_id,
                "Test Resource",
                UInt8[0x0A, 0x0B, 0x0C],
            )

            @test DearDiary.delete(DearDiary.Resource, resource_id)
            @test DearDiary.fetch(DearDiary.Resource, resource_id) |> isnothing
        end
    end
end
