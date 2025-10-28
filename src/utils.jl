abstract type UpsertResult end
struct Created <: UpsertResult end
struct Updated <: UpsertResult end
struct Duplicate <: UpsertResult end
struct Unprocessable <: UpsertResult end
struct Error <: UpsertResult end

"""
    load_config(file::AbstractString)

Load environment variables from a file.

# Arguments
- `file::AbstractString`: The path to the file containing environment variables.

# Returns
An [`APIConfig`](@ref) object containing the loaded environment variables.
"""
function load_config(file::AbstractString)::APIConfig
    host = "localhost"
    port = 9000
    db_file = "trackingapi.db"
    jwt_secret = "trackingapi_secret"
    enable_auth = false
    enable_api = false

    if (file |> isfile)
        env_vars = Dict{String,String}()

        for line in (file |> eachline)
            if !startswith(line, "#") && (line |> !isempty)
                key, value = split(line, "=", limit=2)
                env_vars[key] = value
            end
        end
        host = get(env_vars, "TRACKINGAPI_HOST", host)
        port = haskey(env_vars, "TRACKINGAPI_PORT") ? parse(Int, env_vars["TRACKINGAPI_PORT"]) : port
        db_file = get(env_vars, "TRACKINGAPI_DB_FILE", db_file)
        jwt_secret = get(env_vars, "TRACKINGAPI_JWT_SECRET", jwt_secret)
        enable_auth = haskey(env_vars, "TRACKINGAPI_ENABLE_AUTH") ? parse(Bool, env_vars["TRACKINGAPI_ENABLE_AUTH"]) : enable_auth
        enable_api = haskey(env_vars, "TRACKINGAPI_ENABLE_API") ? parse(Bool, env_vars["TRACKINGAPI_ENABLE_API"]) : enable_api
    end
    return APIConfig(host, port, db_file, jwt_secret, enable_auth, enable_api)
end
