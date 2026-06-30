@with_deardiary_test_db begin
    @testset verbose = true "userpermission service" begin
        @testset verbose = true "create" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")

            @testset "create with no existing user" begin
                _, upsert_result = DearDiary.create_userpermission(
                    "00000000-0000-0000-0000-000000000000",
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result === DearDiary.Unprocessable
            end

            @testset "create with no existing project" begin
                _, upsert_result = DearDiary.create_userpermission(
                    user.id,
                    "00000000-0000-0000-0000-000000000000",
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result === DearDiary.Unprocessable
            end

            @testset "create with existing user and project" begin
                new_user_id, _ = DearDiary.create_user("Gala", "Missy", "gala", "missy")
                userpermission_id, upsert_result = DearDiary.create_userpermission(
                    new_user_id, project_id, false, true, false, false
                )
                @test upsert_result === DearDiary.Created
                @test userpermission_id isa String
                @test !isempty(userpermission_id)
            end

            @testset "create duplicate user permission" begin
                _, upsert_result = DearDiary.create_userpermission(
                    user.id, project_id, false, true, false, false
                )
                @test upsert_result === DearDiary.Duplicate
            end
        end

        @testset verbose = true "get by user id and project id" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")

            @testset "get with existing user and project" begin
                userpermission = DearDiary.get_userpermission(user.id, project_id)

                @test userpermission isa DearDiary.UserPermission
                @test userpermission.user_id == user.id
                @test userpermission.project_id == project_id
            end

            @testset "get with non-existing user" begin
                userpermission = DearDiary.get_userpermission(
                    "00000000-0000-0000-0000-000000000000", project_id
                )

                @test isnothing(userpermission)
            end

            @testset "get with non-existing project" begin
                userpermission = DearDiary.get_userpermission(
                    user.id, "00000000-0000-0000-0000-000000000000"
                )

                @test isnothing(userpermission)
            end

            @testset "get with non-existing user and project" begin
                userpermission = DearDiary.get_userpermission(
                    "00000000-0000-0000-0000-000000000000",
                    "00000000-0000-0000-0000-000000000000",
                )

                @test isnothing(userpermission)
            end
        end

        @testset verbose = true "update" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_userpermission(
                    "00000000-0000-0000-0000-000000000000", true, nothing, nothing, nothing
                )
                @test result === DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")

                userpermission = DearDiary.get_userpermission(user.id, project_id)
                @test userpermission.create_permission == false
                @test userpermission.read_permission == true
                @test userpermission.update_permission == false
                @test userpermission.delete_permission == false

                @test DearDiary.update_userpermission(
                    userpermission.id, true, nothing, nothing, nothing
                ) === DearDiary.Updated
                userpermission = DearDiary.get_userpermission(user.id, project_id)
                @test userpermission.create_permission == true
                @test userpermission.read_permission == true
                @test userpermission.update_permission == false
                @test userpermission.delete_permission == false
            end
        end

        @testset verbose = true "delete" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            userpermission = DearDiary.get_userpermission(user.id, project_id)

            @test DearDiary.delete_userpermission(userpermission.id)
            @test isnothing(DearDiary.get_userpermission(user.id, project_id))
        end

        @testset verbose = true "list by project" begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Listing Project")
            other_user_id, _ = DearDiary.create_user("Pip", "Po", "pip", "po")
            DearDiary.create_userpermission(
                other_user_id, project_id, true, true, false, false
            )

            permissions = DearDiary.get_userpermissions(DearDiary.Project, project_id)
            @test (length(permissions)) == 2
            user_ids = (p -> p.user_id).(permissions)
            @test user.id in user_ids
            @test other_user_id in user_ids
            @test all(p -> p.project_id == project_id, permissions)

            empty_project_id, _ = DearDiary.create_project(user.id, "Empty Project")
            DearDiary.delete_userpermission(
                DearDiary.get_userpermission(user.id, empty_project_id).id
            )
            @test isempty(
                DearDiary.get_userpermissions(DearDiary.Project, empty_project_id)
            )
        end

        @testset verbose = true "list by user" begin
            user = DearDiary.get_user_by_username("default")
            project_a, _ = DearDiary.create_project(user.id, "User Listing A")
            project_b, _ = DearDiary.create_project(user.id, "User Listing B")

            permissions = DearDiary.get_userpermissions(DearDiary.User, user.id)
            project_ids = (p -> p.project_id).(permissions)
            @test project_a in project_ids
            @test project_b in project_ids
            @test all(p -> p.user_id == user.id, permissions)

            ghost_user_id, _ = DearDiary.create_user("No", "Body", "nobody", "secret")
            @test isempty(DearDiary.get_userpermissions(DearDiary.User, ghost_user_id))
        end

        @testset verbose = true "has permission" begin
            permission = DearDiary.UserPermission(
                "00000000-0000-0000-0000-000000000001",
                "00000000-0000-0000-0000-000000000002",
                "00000000-0000-0000-0000-000000000003",
                true,
                false,
                true,
                false,
            )

            @test DearDiary.has_permission(permission, DearDiary.CreatePermission) == true
            @test DearDiary.has_permission(permission, DearDiary.ReadPermission) == false
            @test DearDiary.has_permission(permission, DearDiary.UpdatePermission) == true
            @test DearDiary.has_permission(permission, DearDiary.DeletePermission) == false

            denied = DearDiary.UserPermission(
                "00000000-0000-0000-0000-000000000004",
                "00000000-0000-0000-0000-000000000002",
                "00000000-0000-0000-0000-000000000003",
                false,
                false,
                false,
                false,
            )
            @test DearDiary.has_permission(denied, DearDiary.CreatePermission) == false
            @test DearDiary.has_permission(denied, DearDiary.ReadPermission) == false
            @test DearDiary.has_permission(denied, DearDiary.UpdatePermission) == false
            @test DearDiary.has_permission(denied, DearDiary.DeletePermission) == false
        end
    end
end
