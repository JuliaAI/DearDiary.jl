@testset verbose = true "routes utilities" begin
    @testset verbose = true "get status by upsert result" begin
        upsert_result_to_status = [
            (Tracking.Created(), HTTP.StatusCodes.CREATED),
            (Tracking.Duplicate(), HTTP.StatusCodes.CONFLICT),
            (Tracking.Unprocessable(), HTTP.StatusCodes.UNPROCESSABLE_ENTITY),
            (Tracking.Error(), HTTP.StatusCodes.INTERNAL_SERVER_ERROR),
        ]

        for (upsert_result, status) in upsert_result_to_status
            @test Tracking.get_status_by_upsert_result(upsert_result) == status
        end
    end

    @with_tracking_test_db begin
        @testset verbose = true "admin required macro" begin
            @testset verbose = true "as an admin" begin
                payload = Dict(
                    "username" => "default",
                    "password" => "default",
                ) |> JSON.json
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=payload,
                    status_exception=false,
                )
                token = JSON.parse(response.body |> String)

                create_payload = Dict(
                    "first_name" => "Missy",
                    "last_name" => "Gala",
                    "username" => "missy",
                    "password" => "gala",
                ) |> JSON.json
                response = HTTP.post(
                    "http://127.0.0.1:9000/user";
                    headers=Dict("Authorization" => "Bearer $token"),
                    body=create_payload,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.CREATED
            end

            @testset verbose = true "as a non-admin" begin
                payload = Dict(
                    "username" => "missy",
                    "password" => "gala",
                ) |> JSON.json
                response = HTTP.post(
                    "http://127.0.0.1:9000/auth";
                    body=payload,
                    status_exception=false,
                )
                token = JSON.parse(response.body |> String)

                create_payload = Dict(
                    "first_name" => "Choclo",
                    "last_name" => "Queso",
                    "username" => "choclo",
                    "password" => "queso",
                ) |> JSON.json
                response = HTTP.post(
                    "http://127.0.0.1:9000/user";
                    headers=Dict("Authorization" => "Bearer $token"),
                    body=create_payload,
                    status_exception=false,
                )
                @test response.status == HTTP.StatusCodes.FORBIDDEN
            end
        end
    end
end
