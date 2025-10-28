module TrackingAPI

using Oxygen: headers
using HTTP
using Dates
using Bcrypt
using Compat
using Oxygen
using SQLite
using Memoize
using JSONWebTokens

include("utils.jl")

include("types/config.jl")
include("types/utils.jl")
include("types/user.jl")
include("types/project.jl")
include("types/userpermission.jl")

include("repositories/sql/database.jl")
include("repositories/sql/user.jl")
include("repositories/sql/project.jl")
include("repositories/sql/userpermission.jl")

include("repositories/utils.jl")
include("repositories/database.jl")
include("repositories/user.jl")
include("repositories/project.jl")
include("repositories/userpermission.jl")

include("services/utils.jl")
include("services/user.jl")
include("services/project.jl")
include("services/userpermission.jl")

include("routes/utils.jl")
include("routes/health.jl")
include("routes/user.jl")
include("routes/project.jl")
include("routes/auth.jl")

function AuthMiddleware(handler)
    return function (request::HTTP.Request)
        if api_config.enable_auth
            is_auth_route = request.target |> startswith("/auth") && request.method == "POST"
            is_health_route = request.target |> startswith("/health") && request.method == "GET"

            if !(is_auth_route || is_health_route)
                auth_header = get(request.headers |> Dict, "Authorization", missing)

                if auth_header |> ismissing
                    return json(("message" => "Missing authorization header");
                        status=HTTP.StatusCodes.UNAUTHORIZED)
                end

                token = split(auth_header, " ")[2]
                encoding = JSONWebTokens.HS256(api_config.jwt_secret)

                try
                    payload = JSONWebTokens.decode(encoding, token)

                    is_valid_payload =
                        all(claim -> haskey(payload, claim), ["sub", "id", "exp"])
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
                catch e
                    msg = (e isa ArgumentError) ? e.msg : "Invalid token"
                    return json(("message" => msg);
                        status=HTTP.StatusCodes.UNAUTHORIZED)
                end
            end
        end
        return handler(request)
    end
end


"""
    run(; env_file::String=".env")

Starts the server.

By default, the server will run on `127.0.0.1:9000`. You can change both the host and port
by modifying the `.env` file specific entries. The environment variables are loaded from
the `.env` file by default. You can change the file path by passing the `env_file`
argument.
"""
function run(; env_file::String=".env")
    global api_config = env_file |> load_config

    if !api_config.enable_api
        error("API server is disabled. Set TRACKINGAPI_ENABLE_API=true to enable it.")
    end

    initialize_database()

    health_router = router("/health", tags=["health"])
    @get health_router("/") get_health_handler

    user_router = router("/user", tags=["user"])
    @get user_router("/{id}") get_user_by_id_handler
    @get user_router("/") get_users_handler
    @post user_router("/") create_user_handler
    @patch user_router("/{id}") update_user_handler
    @delete user_router("/{id}") delete_user_handler

    project_router = router("/project", tags=["project"])
    @get project_router("/{id}") get_project_by_id_handler
    @get project_router("/") get_projects_handler
    @post project_router("/") create_project_handler
    @patch project_router("/{id}") update_project_handler
    @delete project_router("/{id}") delete_project_handler

    auth_router = router("/auth", tags=["auth"])
    @post auth_router("/") auth_handler

    serveparallel(; host=api_config.host, port=api_config.port, async=true,
        middleware=[AuthMiddleware])
end

"""
    stop()

Stops the server. Alias for `Oxygen.Core.terminate()`.
"""
stop() = terminate()

end
