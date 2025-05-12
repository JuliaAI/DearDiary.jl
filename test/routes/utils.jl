@testset verbose = true "routes utilities" begin
    @testset verbose = true "get status by upsert result" begin
        upsert_result_to_status = [(TrackingAPI.CREATED, HTTP.StatusCodes.CREATED),
            (TrackingAPI.DUPLICATE, HTTP.StatusCodes.CONFLICT),
            (TrackingAPI.UNPROCESSABLE, HTTP.StatusCodes.UNPROCESSABLE_ENTITY),
            (TrackingAPI.ERROR, HTTP.StatusCodes.INTERNAL_SERVER_ERROR)]

        for (upsert_result, status) in upsert_result_to_status
            @test TrackingAPI.get_status_by_upsert_result(upsert_result) == status
        end
    end
end
