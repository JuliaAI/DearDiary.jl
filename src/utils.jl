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
    db_file = "tracking.db"
    jwt_secret = "tracking_secret"
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
        host = get(env_vars, "TRACKING_HOST", host)

        port = if haskey(env_vars, "TRACKING_PORT")
            parse(Int, env_vars["TRACKING_PORT"])
        else
            port
        end
        db_file = get(env_vars, "TRACKING_DB_FILE", db_file)
        jwt_secret = get(env_vars, "TRACKING_JWT_SECRET", jwt_secret)

        enable_auth = if haskey(env_vars, "TRACKING_ENABLE_AUTH")
            parse(Bool, env_vars["TRACKING_ENABLE_AUTH"])
        else
            enable_auth
        end

        enable_api = if haskey(env_vars, "TRACKING_ENABLE_API")
            parse(Bool, env_vars["TRACKING_ENABLE_API"])
        else
            enable_api
        end
    end
    return APIConfig(host, port, db_file, jwt_secret, enable_auth, enable_api)
end
