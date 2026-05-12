using HTTP
using JSON
using JWTs
using Test
using Dates
using Bcrypt
using Compat
using SQLite

using DearDiary

"""
    create_test_env_file()::String

Create a test environment file for the API server.

# Returns
A string representing the path to the created test environment file.
"""
function create_test_env_file(;
    host::AbstractString="127.0.0.1",
    port::Integer=9000,
    db_file::AbstractString="deardiary_test.db",
    jwt_secret::Union{AbstractString,Nothing}=nothing,
    enable_auth::Bool=false,
)::String
    file = ".env.deardiarytest"

    open(file, "w") do io
        write(io, "DEARDIARY_HOST=$host\n")
        write(io, "DEARDIARY_PORT=$port\n")
        write(io, "DEARDIARY_DB_FILE=$db_file\n")
        write(io, "# DEARDIARY_DB_FILE=comment\n")
        if !(jwt_secret |> isnothing)
            write(io, "DEARDIARY_JWT_SECRET=$jwt_secret\n")
        end
        write(io, "DEARDIARY_ENABLE_AUTH=$enable_auth\n")
    end
    return file
end

macro with_deardiary_test_db(expr)
    quote
        is_api = !(DearDiary._DEARDIARY_APICONFIG |> isnothing)
        if is_api
            DearDiary.initialize_database(
                ; file_name=DearDiary._DEARDIARY_APICONFIG.db_file,
            )
        else
            DearDiary.initialize_database(
                ; file_name="deardiary_offline_test.db",
            )
        end

        try
            $(expr |> esc)
        finally
            if is_api
                DearDiary.close_database()
                DearDiary._DEARDIARY_APICONFIG.db_file |> rm
            else
                DearDiary.close_database()
                "deardiary_offline_test.db" |> rm
            end
        end
    end
end

include("Aqua.jl")


include("utils.jl")

# Functional tests
include("types/parameter.jl")
include("types/utils.jl")
include("types/enums.jl")

include("repositories/database.jl")
include("repositories/user.jl")
include("repositories/project.jl")
include("repositories/userpermission.jl")
include("repositories/experiment.jl")
include("repositories/iteration.jl")
include("repositories/parameter.jl")
include("repositories/metric.jl")
include("repositories/resource.jl")
include("repositories/tag.jl")
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
include("services/tag.jl")

# Auth tests
file = create_test_env_file(; enable_auth=true, jwt_secret="testsecret")
DearDiary.run(; env_file=file)

include("routes/auth.jl")
include("routes/utils.jl")

DearDiary.stop()
file |> rm

# Route tests
file = create_test_env_file()
DearDiary.run(; env_file=file)

include("routes/health.jl")
include("routes/user.jl")
include("routes/project.jl")
include("routes/userpermission.jl")
include("routes/experiment.jl")
include("routes/iteration.jl")
include("routes/parameter.jl")
include("routes/metric.jl")
include("routes/resource.jl")
include("routes/tag.jl")

include("client/client.jl")

DearDiary.stop()
file |> rm
