@with_trackingapi_test_db begin
    @testset verbose = true "user service" begin
        @testset verbose = true "create user" begin
            user_id, user_upsert_result = TrackingAPI.create_user(
                "Missy",
                "Gala",
                "missy",
                "gala",
            )

            @test user_upsert_result isa TrackingAPI.Created
            @test user_id isa Integer
        end

        @testset verbose = true "get_user_by_username" begin
            @testset "get user by existing username" begin
                user = TrackingAPI.get_user_by_username("missy")

                @test user isa TrackingAPI.User
                @test user.id isa Int
                @test user.first_name == "Missy"
                @test user.last_name == "Gala"
                @test user.username == "missy"
                @test CompareHashAndPassword(user.password, "gala")
                @test user.created_date isa DateTime
            end
        end

        @testset "get user by non-existing username" begin
            @test TrackingAPI.get_user_by_username("gala") |> isnothing
        end

        @testset verbose = true "get_users" begin
            TrackingAPI.create_user("Gala", "Missy", "gala", "missy")
            users = TrackingAPI.get_users()

            @test users isa Array{TrackingAPI.User,1}
            @test (users |> length) == 3
        end

        @testset verbose = true "update user" begin
            @test TrackingAPI.update_user(
                2,
                "Ana",
                nothing,
                nothing,
                nothing,
            ) isa TrackingAPI.Updated

            user = TrackingAPI.get_user_by_username("missy")

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete user" begin
            @test TrackingAPI.delete_user(2)

            @test TrackingAPI.get_user_by_username("missy") |> isnothing
        end
    end
end
