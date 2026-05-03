@with_deardiary_test_db begin
    @testset verbose = true "auth" begin
        @testset verbose = true "auth handler with user not found" begin
            payload = Dict("username" => "missy", "password" => "gala") |> JSON.json
            response = HTTP.post(
                "http://127.0.0.1:9000/auth";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.NOT_FOUND
        end

        @testset verbose = true "auth handler with invalid credentials" begin
            payload = Dict("username" => "default", "password" => "gala") |> JSON.json
            response = HTTP.post(
                "http://127.0.0.1:9000/auth";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "auth handler with valid credentials" begin
            payload = Dict("username" => "default", "password" => "default") |> JSON.json
            response = HTTP.post(
                "http://127.0.0.1:9000/auth";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["token_type"] == "Bearer"
            @test data["access_token"] isa String
            @test data["expires_at"] isa Int
            @test data["user"]["username"] == "default"
            @test !haskey(data["user"], "password")
        end

        @testset verbose = true "GET /auth/me" begin
            payload = Dict("username" => "default", "password" => "default") |> JSON.json
            login = HTTP.post(
                "http://127.0.0.1:9000/auth";
                body=payload,
                status_exception=false,
            )
            token = JSON.parse(login.body |> String, Dict{String,Any})["access_token"]

            response = HTTP.get(
                "http://127.0.0.1:9000/auth/me";
                headers=Dict("Authorization" => "Bearer $token"),
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["username"] == "default"
            @test data["is_admin"] == true
            @test !haskey(data, "password")
        end

        @testset verbose = true "GET /auth/me without token" begin
            response = HTTP.get(
                "http://127.0.0.1:9000/auth/me"; status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "POST /auth/refresh with valid token" begin
            login = HTTP.post(
                "http://127.0.0.1:9000/auth";
                body=(
                    Dict("username" => "default", "password" => "default") |> JSON.json
                ),
                status_exception=false,
            )
            login_data = JSON.parse(login.body |> String, Dict{String,Any})
            token = login_data["access_token"]

            response = HTTP.post(
                "http://127.0.0.1:9000/auth/refresh";
                headers=Dict("Authorization" => "Bearer $token"),
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(response.body |> String, Dict{String,Any})
            @test data["access_token"] isa String
            @test data["token_type"] == "Bearer"
            @test data["expires_at"] isa Int
            @test data["user"]["username"] == "default"
            @test !haskey(data["user"], "password")
            @test data["expires_at"] >= login_data["expires_at"]
        end

        @testset verbose = true "POST /auth/refresh without token" begin
            response = HTTP.post(
                "http://127.0.0.1:9000/auth/refresh"; status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "POST /auth/refresh with expired token" begin
            claims = Dict(
                "sub" => "default",
                "id" => 1,
                "exp" => ((now() - Hour(1)) |> datetime2unix |> floor) |> Int,
            )
            jwt = JWT(; payload=claims)
            key = JWKSymmetric(
                JWTs.MD_SHA256,
                DearDiary._DEARDIARY_APICONFIG.jwt_secret |> Array{UInt8,1},
            )
            sign!(jwt, key)

            response = HTTP.post(
                "http://127.0.0.1:9000/auth/refresh";
                headers=Dict("Authorization" => "Bearer $(jwt |> string)"),
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "issued tokens are valid for ~24h" begin
            login = HTTP.post(
                "http://127.0.0.1:9000/auth";
                body=(
                    Dict("username" => "default", "password" => "default") |> JSON.json
                ),
                status_exception=false,
            )
            data = JSON.parse(login.body |> String, Dict{String,Any})
            now_unix = ((now() |> datetime2unix) |> floor) |> Int
            ttl_seconds = data["expires_at"] - now_unix
            @test ttl_seconds > 23 * 3600
            @test ttl_seconds <= 24 * 3600
        end

        @testset verbose = true "without authorization header" begin
            response = HTTP.get("http://127.0.0.1:9000/user/1"; status_exception=false)

            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "with authorization header" begin
            @testset "with valid JWT" begin
                payload = Dict(
                    "username" => "default",
                    "password" => "default",
                ) |> JSON.json
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=payload,
                    status_exception=false,
                )

                token = JSON.parse(response.body |> String, Dict{String,Any})["access_token"]

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.OK
            end

            @testset "with invalid JWT validation process" begin
                token = "invalid.token.string"

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test response.body |> String |> contains("Invalid token")
            end

            @testset "with invalid JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => 1,
                    "exp" => ((now() + Hour(1)) |> datetime2unix |> floor) |> Int,
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(JWTs.MD_SHA256, "incorrect secret" |> Array{UInt8,1})
                sign!(jwt, key)
                token = jwt |> string

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test response.body |> String |> contains("Invalid token")
            end

            @testset "with valid JWT but empty payload" begin
                jwt = JWT(; payload=Dict())
                key = JWKSymmetric(
                    JWTs.MD_SHA256,
                    DearDiary._DEARDIARY_APICONFIG.jwt_secret |> Array{UInt8,1},
                )
                sign!(jwt, key)
                token = jwt |> string

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test response.body |> String |> contains("Invalid token payload")
            end

            @testset "with expired JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => 1,
                    "exp" => ((now() - Hour(1)) |> datetime2unix |> floor) |> Int,
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(
                    JWTs.MD_SHA256,
                    DearDiary._DEARDIARY_APICONFIG.jwt_secret |> Array{UInt8,1},
                )
                sign!(jwt, key)
                token = jwt |> string

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test response.body |> String |> contains("Token has expired")
            end

            @testset "with string as id in JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => "one",
                    "exp" => ((now() + Hour(1)) |> datetime2unix |> floor) |> Int,
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(
                    JWTs.MD_SHA256,
                    DearDiary._DEARDIARY_APICONFIG.jwt_secret |> Array{UInt8,1},
                )
                sign!(jwt, key)
                token = jwt |> string

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test response.body |> String |> contains("Invalid token payload")
            end

            @testset "with zero as id in JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => 0,
                    "exp" => ((now() + Hour(1)) |> datetime2unix |> floor) |> Int,
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(
                    JWTs.MD_SHA256,
                    DearDiary._DEARDIARY_APICONFIG.jwt_secret |> Array{UInt8,1},
                )
                sign!(jwt, key)
                token = jwt |> string

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test response.body |> String |> contains("Invalid token payload")
            end

            @testset "with non-existing user id in JWT" begin
                claims = Dict(
                    "sub" => "default",
                    "id" => 9999,
                    "exp" => ((now() + Hour(1)) |> datetime2unix |> floor) |> Int,
                )
                jwt = JWT(; payload=claims)
                key = JWKSymmetric(
                    JWTs.MD_SHA256,
                    DearDiary._DEARDIARY_APICONFIG.jwt_secret |> Array{UInt8,1},
                )
                sign!(jwt, key)
                token = jwt |> string

                response = HTTP.get(
                    "http://127.0.0.1:9000/user/1";
                    headers=Dict("Authorization" => "Bearer $token"),
                    status_exception=false,
                )

                @test response.status == HTTP.StatusCodes.UNAUTHORIZED
                @test response.body |> String |> contains("User not found")
            end
        end
    end
end
