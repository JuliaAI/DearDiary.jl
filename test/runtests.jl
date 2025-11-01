using HTTP
using JSON
using Test
using Dates
using Bcrypt
using Compat
using SQLite
using Memoize

using Tracking

"""
    create_test_env_file()::String

Create a test environment file for the API server.

# Returns
A string representing the path to the created test environment file.
"""
function create_test_env_file(;
    host::String="127.0.0.1",
    db_file::String="tracking_test.db",
    jwt_secret::Union{String,Nothing}=nothing,
    enable_auth::Bool=false,
    enable_api::Bool=false
)::String
    file = ".env.trackingtest"

    open(file, "w") do io
        write(io, "TRACKING_HOST=$host\n")
        write(io, "TRACKING_DB_FILE=$db_file\n")
        write(io, "# TRACKING_DB_FILE=comment\n")
        if !(jwt_secret |> isnothing)
            write(io, "TRACKING_JWT_SECRET=$jwt_secret\n")
        end
        write(io, "TRACKING_ENABLE_AUTH=$enable_auth\n")
        write(io, "TRACKING_ENABLE_API=$enable_api\n")
    end
    return file
end

macro with_tracking_test_db(expr)
    quote
        Tracking.initialize_database()

        try
            $(expr |> esc)
        finally
            if isdefined(Main, :api_config)
                "tracking_test.db" |> rm
            else
                "tracking.db" |> rm
            end
            Tracking.get_database |> memoize_cache |> empty!
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
include("repositories/experiment.jl")
include("repositories/iteration.jl")
include("repositories/parameter.jl")
include("repositories/metric.jl")
include("repositories/resource.jl")
include("repositories/utils.jl")

include("services/user.jl")
include("services/utils.jl")
include("services/project.jl")
include("services/userpermission.jl")
include("services/experiment.jl")
include("services/iteration.jl")
include("services/parameter.jl")
include("services/metric.jl")
include("services/resource.jl")

file |> rm

# Auth tests
file = create_test_env_file(; enable_auth=true, enable_api=true)
Tracking.run(; env_file=file)

include("routes/auth.jl")
include("routes/utils.jl")

Tracking.stop()
file |> rm

# Route tests
file = create_test_env_file(; enable_api=true)
Tracking.run(; env_file=file)

include("routes/health.jl")
include("routes/user.jl")
include("routes/project.jl")
include("routes/userpermission.jl")
include("routes/experiment.jl")
include("routes/iteration.jl")
include("routes/parameter.jl")
include("routes/metric.jl")
include("routes/resource.jl")

Tracking.stop()
file |> rm
