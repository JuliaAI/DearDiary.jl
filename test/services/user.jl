@with_deardiary_test_db begin
    @testset verbose = true "user service" begin
        @testset verbose = true "create user" begin
            user_id, user_upsert_result = DearDiary.create_user(
                "Missy", "Gala", "missy", "gala"
            )

            @test user_upsert_result === DearDiary.Created
            @test user_id isa Integer
        end

        @testset verbose = true "get user by username" begin
            @testset "get user by existing username" begin
                user = DearDiary.get_user("missy")

                @test user isa DearDiary.User
                @test user.id isa Int
                @test user.first_name == "Missy"
                @test user.last_name == "Gala"
                @test user.username == "missy"
                @test CompareHashAndPassword(user.password, "gala")
                @test user.created_date isa DateTime
            end
        end

        @testset "get user by non-existing username" begin
            @test isnothing(DearDiary.get_user("gala"))
        end

        @testset verbose = true "get_users" begin
            DearDiary.create_user("Gala", "Missy", "gala", "missy")
            users = DearDiary.get_users()

            @test users isa Array{DearDiary.User,1}
            @test (length(users)) == 3
        end

        @testset verbose = true "update user" begin
            @testset "with non-existing user id" begin
                @test DearDiary.update_user(9999, "Ana", "Gala", "Choclo", true) ===
                    DearDiary.Unprocessable
            end

            @testset "with existing user id" begin
                @test DearDiary.update_user(2, "Ana", nothing, "Choclo", nothing) ===
                    DearDiary.Updated

                user = DearDiary.get_user("missy")

                @test user.first_name == "Ana"
                @test user.last_name == "Gala"
            end
        end

        @testset verbose = true "delete user" begin
            @test DearDiary.delete_user(2)

            @test isnothing(DearDiary.get_user("missy"))
        end
    end
end
