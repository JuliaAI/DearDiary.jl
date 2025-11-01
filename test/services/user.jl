@with_tracking_test_db begin
    @testset verbose = true "user service" begin
        @testset verbose = true "create user" begin
            user_id, user_upsert_result = Tracking.create_user(
                "Missy",
                "Gala",
                "missy",
                "gala",
            )

            @test user_upsert_result isa Tracking.Created
            @test user_id isa Integer
        end

        @testset verbose = true "get user by username" begin
            @testset "get user by existing username" begin
                user = Tracking.get_user("missy")

                @test user isa Tracking.User
                @test user.id isa Int
                @test user.first_name == "Missy"
                @test user.last_name == "Gala"
                @test user.username == "missy"
                @test CompareHashAndPassword(user.password, "gala")
                @test user.created_date isa DateTime
            end
        end

        @testset "get user by non-existing username" begin
            @test Tracking.get_user("gala") |> isnothing
        end

        @testset verbose = true "get_users" begin
            Tracking.create_user("Gala", "Missy", "gala", "missy")
            users = Tracking.get_users()

            @test users isa Array{Tracking.User,1}
            @test (users |> length) == 3
        end

        @testset verbose = true "update user" begin
            @test Tracking.update_user(
                2,
                "Ana",
                nothing,
                nothing,
                nothing,
            ) isa Tracking.Updated

            user = Tracking.get_user("missy")

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete user" begin
            @test Tracking.delete_user(2)

            @test Tracking.get_user("missy") |> isnothing
        end
    end
end
