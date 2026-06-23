@testset verbose = true "health route" begin
    response = HTTP.get("http://127.0.0.1:9000/health"; status_exception=false)

    @test response.status == HTTP.StatusCodes.OK

    data = JSON.parse(String(response.body), Dict{String,Any})
    data_keys = keys(data)

    @test "app_name" in data_keys
    @test "package_version" in data_keys
    @test "server_time" in data_keys

    @test data["app_name"] == "DearDiary"
    @test (VersionNumber(data["package_version"])) == (pkgversion(DearDiary))
end
