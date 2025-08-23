@testset verbose = true "health route" begin
    response = HTTP.get("http://127.0.0.1:9000/health"; status_exception=false)

    @test response.status == HTTP.StatusCodes.OK

    data = response.body |> String |> JSON.parse
    data_keys = data |> keys

    @test "app_name" in data_keys
    @test "package_version" in data_keys
    @test "server_time" in data_keys

    @test data["app_name"] == "TrackingAPI"
    @test (data["package_version"] |> VersionNumber) == (TrackingAPI |> pkgversion)
end
