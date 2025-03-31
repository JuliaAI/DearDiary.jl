module TrackingAPI

using HTTP
using Dates
using Compat
using Oxygen
using SQLite
using Memoize

include("utils.jl")

include("types/enums.jl")
include("types/user.jl")

include("repositories/sql/database.jl")
include("repositories/sql/user.jl")

include("repositories/utils.jl")
include("repositories/database.jl")
include("repositories/user.jl")

include("services/user.jl")

include("routes/utils.jl")
include("routes/health.jl")
include("routes/user.jl")

"""
    run(; host::String="127.0.0.1", port::Int=9000, env_file::String=".env")

Starts the server.

By default, the server will run on `127.0.0.1:9000`. You can change the host and port by
passing the `host` and `port` arguments. The environment variables are loaded from the
`.env` file by default. You can change the file path by passing the `env_file` argument.
"""
function run(; host::String="127.0.0.1", port::Int=9000, env_file::String=".env")
    env_file |> load_env_file
    initialize_database()

    health_router = router("/health", tags=["health"])
    @get health_router("/") get_health_handler

    user_router = router("/user", tags=["user"])
    @get user_router("/{username}") get_user_by_username_handler
    @get user_router("/") get_users_handler
    @post user_router("/") create_user_handler

    serveparallel(; host=host, port=port, async=true)
end

"""
    stop()

Stops the server. Alias for `Oxygen.Core.terminate()`.
"""
stop() = terminate()

end
