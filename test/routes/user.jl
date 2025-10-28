@with_trackingapi_test_db begin
    @testset verbose = true "user routes" begin
        @testset verbose = true "create user" begin
            payload = Dict("first_name" => "Missy", "last_name" => "Gala",
                "username" => "missy", "password" => "gala") |> JSON.json
            response = HTTP.post("http://127.0.0.1:9000/user"; body=payload, status_exception=false)
            username_user = TrackingAPI.get_user_by_username("missy")

            @test response.status == HTTP.StatusCodes.CREATED
            data = response.body |> String |> JSON.parse
            @test data["user_id"] == username_user.id
        end

        @testset verbose = true "get user by id" begin
            username_user = TrackingAPI.get_user_by_username("missy")
            response = HTTP.get("http://127.0.0.1:9000/user/$(username_user.id)"; status_exception=false)

            @test response.status == HTTP.StatusCodes.OK
            data = response.body |> String |> JSON.parse
            user = data |> TrackingAPI.User

            @test user.id isa Int
            @test user.first_name == "Missy"
            @test user.last_name == "Gala"
            @test user.username == "missy"
            @test user.created_date isa DateTime
        end

        @testset verbose = true "get users" begin
            payload = Dict("first_name" => "Gala", "last_name" => "Missy",
                "username" => "gala", "password" => "missy") |> JSON.json
            HTTP.post("http://127.0.0.1:9000/user"; body=payload, status_exception=false)

            response = HTTP.get("http://127.0.0.1:9000/user/"; status_exception=false)

            @test response.status == HTTP.StatusCodes.OK
            data = response.body |> String |> JSON.parse
            users = data .|> TrackingAPI.User

            @test users isa Array{TrackingAPI.User,1}
            @test (users |> length) == 3
        end

        @testset verbose = true "update user" begin
            username_user = TrackingAPI.get_user_by_username("missy")
            payload = Dict("first_name" => "Ana", "last_name" => nothing,
                "password" => nothing) |> JSON.json
            response = HTTP.patch("http://127.0.0.1:9000/user/$(username_user.id)"; body=payload, status_exception=false)

            @test response.status == HTTP.StatusCodes.OK
            data = response.body |> String |> JSON.parse
            @test data["message"] == "UPDATED"

            response = HTTP.get("http://127.0.0.1:9000/user/$(username_user.id)"; status_exception=false)
            data = response.body |> String |> JSON.parse
            user = data |> TrackingAPI.User

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete user" begin
            username_user = TrackingAPI.get_user_by_username("missy")
            response = HTTP.delete("http://127.0.0.1:9000/user/$(username_user.id)"; status_exception=false)
            @test response.status == HTTP.StatusCodes.OK
            data = response.body |> String |> JSON.parse
            @test data["message"] == "OK"
        end
    end
end
