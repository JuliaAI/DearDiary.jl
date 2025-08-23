@testset verbose = true "service utilities" begin
    @testset verbose = true "transform object to Dict" begin
        user = TrackingAPI.User(1, "Missy", "Gala", "missy", "gala",
            DateTime("2021-01-01T00:00:00"), false)
        user_dict = user |> TrackingAPI.Dict

        @test user_dict isa Dict
        @test user_dict[:id] == 1
        @test user_dict[:first_name] == "Missy"
        @test user_dict[:last_name] == "Gala"
        @test user_dict[:username] == "missy"
        @test user_dict[:password] == "gala"
        @test user_dict[:created_at] == DateTime("2021-01-01T00:00:00")
        @test user_dict[:is_admin] == false
    end

    @testset verbose = true "compare result type object fields" begin
        user = TrackingAPI.User(1, "Missy", "Gala", "missy", "gala",
            DateTime("2021-01-01T00:00:00"), false)

        @test !(TrackingAPI.compare_object_fields(user; id=1))
        @test TrackingAPI.compare_object_fields(user; id=100)
    end
end
