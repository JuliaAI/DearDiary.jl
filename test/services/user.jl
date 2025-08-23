@with_trackingapi_test_db begin
    @testset verbose = true "user service" begin
        @testset verbose = true "create user" begin
            payload = TrackingAPI.UserCreatePayload("Missy", "Gala", "missy", "gala")
            upsert_result = TrackingAPI.create_user(payload)

            @test upsert_result == TrackingAPI.CREATED
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
                @test user.created_at isa DateTime
            end
        end

        @testset "get user by non-existing username" begin
            @test TrackingAPI.get_user_by_username("gala") |> isnothing
        end

        @testset verbose = true "get_users" begin
            payload = TrackingAPI.UserCreatePayload("Gala", "Missy", "gala", "missy")
            TrackingAPI.create_user(payload)
            users = TrackingAPI.get_users()

            @test users isa Array{TrackingAPI.User,1}
            @test (users |> length) == 2
        end

        @testset verbose = true "update user" begin
            user_payload = TrackingAPI.UserUpdatePayload("Ana", nothing, nothing, nothing)
            @test TrackingAPI.update_user(1, user_payload) == TrackingAPI.UPDATED

            user = TrackingAPI.get_user_by_username("missy")

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete user" begin
            @test TrackingAPI.delete_user(1)

            @test TrackingAPI.get_user_by_username("missy") |> isnothing
        end
    end
end
