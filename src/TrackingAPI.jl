module TrackingAPI

using Oxygen: headers
using HTTP
using JWTs
using Dates
using Bcrypt
using Compat
using Oxygen
using SQLite
using Memoize

include("utils.jl")

include("types/config.jl")
include("types/enums.jl")
include("types/utils.jl")
include("types/user.jl")
include("types/project.jl")
include("types/userpermission.jl")
include("types/experiment.jl")
include("types/iteration.jl")
include("types/parameter.jl")
include("types/metric.jl")
include("types/resource.jl")

include("repositories/sql/database.jl")
include("repositories/sql/user.jl")
include("repositories/sql/project.jl")
include("repositories/sql/userpermission.jl")
include("repositories/sql/experiment.jl")
include("repositories/sql/iteration.jl")
include("repositories/sql/parameter.jl")
include("repositories/sql/metric.jl")
include("repositories/sql/resource.jl")

include("repositories/utils.jl")
include("repositories/database.jl")
include("repositories/user.jl")
include("repositories/project.jl")
include("repositories/userpermission.jl")
include("repositories/experiment.jl")
include("repositories/iteration.jl")
include("repositories/parameter.jl")
include("repositories/metric.jl")
include("repositories/resource.jl")

include("services/utils.jl")
include("services/user.jl")
include("services/project.jl")
include("services/userpermission.jl")
include("services/experiment.jl")
include("services/iteration.jl")
include("services/parameter.jl")
include("services/metric.jl")
include("services/resource.jl")

include("routes/utils.jl")
include("routes/user.jl")
include("routes/project.jl")
include("routes/userpermission.jl")
include("routes/experiment.jl")
include("routes/iteration.jl")
include("routes/parameter.jl")
include("routes/metric.jl")
include("routes/resource.jl")
include("routes/auth.jl")

function AuthMiddleware(handler)
    return function (request::HTTP.Request)
        if api_config.enable_auth
            is_auth_route = request.target |> startswith("/auth") && request.method == "POST"
            is_health_route = request.target |> startswith("/health") && request.method == "GET"

            if !(is_auth_route || is_health_route)
                auth_header = get(request.headers |> Dict, "Authorization", missing)

                if auth_header |> ismissing
                    return json(
                        ("message" => "Missing authorization header");
                        status=HTTP.StatusCodes.UNAUTHORIZED,
                    )
                end

                token = split(auth_header, " ")[2] |> string
                jwt = JWT(; jwt=token)
                key = JWKSymmetric(JWTs.MD_SHA256, api_config.jwt_secret |> Array{UInt8,1})
                validate!(jwt, key)

                if jwt |> isvalid
                    payload = jwt |> claims

                    is_valid_payload = all(
                        claim -> haskey(payload, claim),
                        ["sub", "id", "exp"],
                    )
                    if payload |> isnothing || !is_valid_payload
                        throw(ArgumentError("Invalid token payload"))
                    end

                    exp = get(payload, "exp", nothing)
                    if exp |> isnothing || (exp isa Integer && exp < (now() |> Dates.value))
                        throw(ArgumentError("Token expired"))
                    end

                    user_id = get(payload, "id", 0)
                    is_valid_user_id = user_id isa Int && user_id > 0
                    if !is_valid_user_id
                        throw(ArgumentError("Invalid token payload"))
                    end

                    user = get_user_by_id(user_id)
                    if user |> isnothing
                        throw(ArgumentError("User not found"))
                    end
                    request.context[:user] = user
                else
                    return json(
                        ("message" => "Invalid token"),
                        status=HTTP.StatusCodes.UNAUTHORIZED,
                    )
                end
            end
        end
        return handler(request)
    end
end


"""
    run(; env_file::String=".env")

Starts the server.

By default, the server will run on `127.0.0.1:9000`. You can change both the host and port by modifying the `.env` file specific entries. The environment variables are loaded from the `.env` file by default. You can change the file path by passing the `env_file` argument.
"""
function run(; env_file::String=".env")
    global api_config = env_file |> load_config

    if !api_config.enable_api
        error("API server is disabled. Set TRACKINGAPI_ENABLE_API=true to enable it.")
    end

    initialize_database()

    @get "/health" function (::HTTP.Request)
        data = Dict(
            "app_name" => TrackingAPI |> nameof |> String,
            "package_version" => TrackingAPI |> pkgversion,
            "server_time" => Dates.now(),
        )
        return json(data; status=HTTP.StatusCodes.OK)
    end

    setup_user_routes()
    setup_project_routes()
    setup_userpermission_routes()
    setup_experiment_routes()
    setup_iteration_routes()
    setup_parameter_routes()
    setup_metric_routes()
    setup_resource_routes()
    setup_auth_routes()

    serveparallel(;
        host=api_config.host,
        port=api_config.port,
        async=true,
        middleware=[AuthMiddleware],
    )
end

"""
    stop()

Stops the server. Alias for `Oxygen.Core.terminate()`.
"""
stop() = terminate()

end
