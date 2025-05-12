"""
    get_health_handler()

!!! warning
    This function is for route handling and should not be called directly.
"""
function get_health_handler()
    app_name = "TrackingAPI"
    package_version = TrackingAPI |> pkgversion
    server_time = Dates.now()

    data = Dict("app_name" => app_name, "package_version" => package_version,
        "server_time" => server_time)
    return json(data; status=HTTP.StatusCodes.OK)
end
