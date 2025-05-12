@with_trackingapi_test_db begin
    @testset verbose = true "auth" begin
        @testset verbose = true "auth handler with user not found" begin
            payload = Dict("username" => "missy", "password" => "gala") |> JSON.json
            response = HTTP.post("http://127.0.0.1:9000/auth"; body=payload, status_exception=false)

            @test response.status == HTTP.StatusCodes.NOT_FOUND
        end

        @testset verbose = true "auth handler with invalid credentials" begin
            payload = Dict("username" => "default", "password" => "gala") |> JSON.json
            response = HTTP.post("http://127.0.0.1:9000/auth"; body=payload, status_exception=false)

            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "auth handler with valid credentials" begin
            payload = Dict("username" => "default", "password" => "default") |> JSON.json
            response = HTTP.post("http://127.0.0.1:9000/auth"; body=payload, status_exception=false)

            data = response.body |> String |> JSON.parse

            @test response.status == HTTP.StatusCodes.OK
        end

        @testset verbose = true "without authorization header" begin
            response = HTTP.get("http://127.0.0.1:9000/user/default"; status_exception=false)

            @test response.status == HTTP.StatusCodes.UNAUTHORIZED
        end

        @testset verbose = true "with authorization header" begin
            @testset verbose = true "with valid JWT" begin
                payload = Dict("username" => "default", "password" => "default") |> JSON.json
                response = HTTP.post("http://127.0.0.1:9000/auth"; body=payload, status_exception=false)

                token = response.body |> String |> JSON.parse

                response = HTTP.get("http://127.0.0.1:9000/user/default";
                    headers=Dict("Authorization" => "Bearer $token"), status_exception=false)

                @test response.status == HTTP.StatusCodes.OK
            end
        end
    end
end
