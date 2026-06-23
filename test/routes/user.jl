@with_deardiary_test_db begin
    @testset verbose = true "user routes" begin
        @testset verbose = true "create user" begin
            payload = JSON.json(
                Dict(
                    "first_name" => "Missy",
                    "last_name" => "Gala",
                    "username" => "missy",
                    "password" => "gala",
                ),
            )
            response = HTTP.post(
                "http://127.0.0.1:9000/user"; body=payload, status_exception=false
            )
            username_user = DearDiary.get_user("missy")

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["user_id"] == username_user.id
        end

        @testset verbose = true "get user by id" begin
            username_user = DearDiary.get_user("missy")
            response = HTTP.get(
                "http://127.0.0.1:9000/user/$(username_user.id)"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test !haskey(data, "password")
            user = DearDiary.UserResponse(data)

            @test user.id isa Int
            @test user.first_name == "Missy"
            @test user.last_name == "Gala"
            @test user.username == "missy"
            @test user.created_date isa DateTime
        end

        @testset verbose = true "get users" begin
            payload = JSON.json(
                Dict(
                    "first_name" => "Gala",
                    "last_name" => "Missy",
                    "username" => "gala",
                    "password" => "missy",
                ),
            )
            HTTP.post("http://127.0.0.1:9000/user"; body=payload, status_exception=false)

            response = HTTP.get("http://127.0.0.1:9000/user/"; status_exception=false)

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Array{Dict{String,Any},1})
            users = DearDiary.UserResponse.(data)

            @test users isa Array{DearDiary.UserResponse,1}
            @test (length(users)) == 3
            @test all(d -> !haskey(d, "password"), data)
        end

        @testset verbose = true "update user" begin
            username_user = DearDiary.get_user("missy")
            payload = JSON.json(
                Dict("first_name" => "Ana", "last_name" => nothing, "password" => nothing)
            )
            response = HTTP.patch(
                "http://127.0.0.1:9000/user/$(username_user.id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get(
                "http://127.0.0.1:9000/user/$(username_user.id)"; status_exception=false
            )
            data = JSON.parse(String(response.body), Dict{String,Any})
            user = DearDiary.UserResponse(data)

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete user" begin
            username_user = DearDiary.get_user("missy")
            response = HTTP.delete(
                "http://127.0.0.1:9000/user/$(username_user.id)"; status_exception=false
            )
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "OK"
        end
    end
end
