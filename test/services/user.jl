@with_trackingapi_test_db begin
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

        @testset "get user by non-existing username" begin
            @test TrackingAPI.get_user_by_username("gala") |> isnothing
        end
    end

    @testset verbose = true "get_users" begin
        payload = TrackingAPI.UserCreatePayload("Gala", "Missy", "gala", "missy")
        TrackingAPI.create_user(payload)
        users = TrackingAPI.get_users()

        @test users isa Array{TrackingAPI.User,1}
        @test (users |> length) == 2
    end
end
