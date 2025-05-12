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
    enable_auth::Bool=false)::String
    file = ".env.trackingapitest"

    open(file, "w") do io
        write(io, "TRACKINGAPI_HOST=$host\n")
        write(io, "TRACKINGAPI_DB_FILE=$db_file\n")
        write(io, "# TRACKINGAPI_DB_FILE=comment\n")
        if !(jwt_secret |> isnothing)
            write(io, "TRACKINGAPI_JWT_SECRET=$jwt_secret\n")
        end
        write(io, "TRACKINGAPI_ENABLE_AUTH=$enable_auth\n")
    end
    return file
end

macro with_trackingapi_test_db(expr)
    quote
        TrackingAPI.initialize_database()

        try
            $(expr |> esc)
        finally
            "trackingapi_test.db" |> rm
            TrackingAPI.get_database |> memoize_cache |> empty!
        end
    end
end

include("utils.jl")

# Auth tests
file = create_test_env_file(; enable_auth=true)
TrackingAPI.run(; env_file=file)

include("routes/auth.jl")

TrackingAPI.stop()
file |> rm

# Functional tests
file = create_test_env_file()
TrackingAPI.run(; env_file=file)

include("repositories/database.jl")
include("repositories/user.jl")
include("repositories/utils.jl")

include("services/user.jl")

include("routes/utils.jl")
include("routes/health.jl")
include("routes/user.jl")

TrackingAPI.stop()
file |> rm
