@with_deardiary_test_db begin
    @testset verbose = true "userpermission service" begin
        @testset verbose = true "create" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")

            @testset "create with no existing user" begin
                _, upsert_result = DearDiary.create_userpermission(
                    9999,
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa DearDiary.Unprocessable
            end

            @testset "create with no existing project" begin
                _, upsert_result = DearDiary.create_userpermission(
                    user.id,
                    9999,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa DearDiary.Unprocessable
            end

            @testset "create with existing user and project" begin
                new_user_id, _ = DearDiary.create_user("Gala", "Missy", "gala", "missy")
                userpermission_id, upsert_result = DearDiary.create_userpermission(
                    new_user_id,
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa DearDiary.Created
                @test userpermission_id isa Integer
            end

            @testset "create duplicate user permission" begin
                _, upsert_result = DearDiary.create_userpermission(
                    user.id,
                    project_id,
                    false,
                    true,
                    false,
                    false,
                )
                @test upsert_result isa DearDiary.Duplicate
            end
        end

        @testset verbose = true "get by user id and project id" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")

            @testset "get with existing user and project" begin
                userpermission = DearDiary.get_userpermission(
                    user.id,
                    project_id,
                )

                @test userpermission isa DearDiary.UserPermission
                @test userpermission.user_id == user.id
                @test userpermission.project_id == project_id
            end

            @testset "get with non-existing user" begin
                userpermission = DearDiary.get_userpermission(
                    9999,
                    project_id,
                )

                @test userpermission |> isnothing
            end

            @testset "get with non-existing project" begin
                userpermission = DearDiary.get_userpermission(user.id, 9999)

                @test userpermission |> isnothing
            end

            @testset "get with non-existing user and project" begin
                userpermission = DearDiary.get_userpermission(9999, 9999)

                @test userpermission |> isnothing
            end
        end

        @testset verbose = true "update" begin
            @testset "with non-existing id" begin
                result = DearDiary.update_userpermission(
                    9999,
                    true,
                    nothing,
                    nothing,
                    nothing,
                )
                @test result isa DearDiary.Unprocessable
            end

            @testset "with existing id" begin
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Test Project")

                userpermission = DearDiary.get_userpermission(user.id, project_id)
                @test userpermission.create_permission == false
                @test userpermission.read_permission == true
                @test userpermission.update_permission == false
                @test userpermission.delete_permission == false

                @test DearDiary.update_userpermission(
                    userpermission.id,
                    true,
                    nothing,
                    nothing,
                    nothing,
                ) isa DearDiary.Updated
                userpermission = DearDiary.get_userpermission(user.id, project_id)
                @test userpermission.create_permission == true
                @test userpermission.read_permission == true
                @test userpermission.update_permission == false
                @test userpermission.delete_permission == false
            end
        end

        @testset verbose = true "delete" begin
            user = DearDiary.get_user("default")
            project_id, _ = DearDiary.create_project(user.id, "Test Project")
            userpermission = DearDiary.get_userpermission(user.id, project_id)

            @test DearDiary.delete_userpermission(userpermission.id)
            @test DearDiary.get_userpermission(user.id, project_id) |> isnothing
        end

        @testset verbose = true "has permission" begin
            permission = DearDiary.UserPermission(1, 1, 1, true, false, true, false)

            @test DearDiary.has_permission(permission, DearDiary.CreatePermission) == true
            @test DearDiary.has_permission(permission, DearDiary.ReadPermission) == false
            @test DearDiary.has_permission(permission, DearDiary.UpdatePermission) == true
            @test DearDiary.has_permission(permission, DearDiary.DeletePermission) == false

            denied = DearDiary.UserPermission(2, 1, 1, false, false, false, false)
            @test DearDiary.has_permission(denied, DearDiary.CreatePermission) == false
            @test DearDiary.has_permission(denied, DearDiary.ReadPermission) == false
            @test DearDiary.has_permission(denied, DearDiary.UpdatePermission) == false
            @test DearDiary.has_permission(denied, DearDiary.DeletePermission) == false
        end
    end
end
