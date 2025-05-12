@testset verbose = true "health route" begin
    response = HTTP.get("http://127.0.0.1:9000/health"; status_exception=false)

    @assert response.status == HTTP.StatusCodes.OK

    data = response.body |> String |> JSON.parse
    data_keys = data |> keys

    @assert "app_name" in data_keys
    @assert "package_version" in data_keys
    @assert "server_time" in data_keys

    @assert data["app_name"] == "TrackingAPI"
    @assert (data["package_version"] |> VersionNumber) == (TrackingAPI |> pkgversion)
end
