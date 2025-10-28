using HTTP
using JSON
using Test
using Dates
using Bcrypt
using Compat
using SQLite
using Memoize

using TrackingAPI


"""
    create_test_env_file()::String

Create a test environment file for the API server.

# Returns
A string representing the path to the created test environment file.
"""
function create_test_env_file(; host::String="127.0.0.1",
    db_file::String="trackingapi_test.db", jwt_secret::Union{String,Nothing}=nothing,
    enable_auth::Bool=false, enable_api::Bool=false)::String
    file = ".env.trackingapitest"

    open(file, "w") do io
        write(io, "TRACKINGAPI_HOST=$host\n")
        write(io, "TRACKINGAPI_DB_FILE=$db_file\n")
        write(io, "# TRACKINGAPI_DB_FILE=comment\n")
        if !(jwt_secret |> isnothing)
            write(io, "TRACKINGAPI_JWT_SECRET=$jwt_secret\n")
        end
        write(io, "TRACKINGAPI_ENABLE_AUTH=$enable_auth\n")
        write(io, "TRACKINGAPI_ENABLE_API=$enable_api\n")
    end
    return file
end

macro with_trackingapi_test_db(expr)
    quote
        TrackingAPI.initialize_database()

        try
            $(expr |> esc)
        finally
            if isdefined(Main, :api_config)
                "trackingapi_test.db" |> rm
            else
                "trackingapi.db" |> rm
            end
            TrackingAPI.get_database |> memoize_cache |> empty!
        end
    end
end

include("utils.jl")

# Functional tests
file = create_test_env_file()

include("types/utils.jl")

include("repositories/database.jl")
include("repositories/user.jl")
include("repositories/project.jl")
include("repositories/userpermission.jl")
include("repositories/utils.jl")

include("services/user.jl")
include("services/utils.jl")
include("services/project.jl")
include("services/userpermission.jl")

file |> rm

# Auth tests
file = create_test_env_file(; enable_auth=true, enable_api=true)
TrackingAPI.run(; env_file=file)

include("routes/auth.jl")
include("routes/utils.jl")

TrackingAPI.stop()
file |> rm

# Route tests
file = create_test_env_file(; enable_api=true)
TrackingAPI.run(; env_file=file)

include("routes/health.jl")
include("routes/user.jl")
include("routes/project.jl")
include("routes/userpermission.jl")

TrackingAPI.stop()
file |> rm
