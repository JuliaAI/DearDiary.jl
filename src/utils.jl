"""
    load_config(file::AbstractString)::APIConfig

Load environment variables from a file.

# Arguments
- `file::AbstractString`: The path to the file containing environment variables.

# Returns
An [`APIConfig`](@ref) object containing the loaded environment variables.
"""
function load_config(file::AbstractString)::APIConfig
    host = "127.0.0.1"
    port = 9000
    db_file = "deardiary.db"
    jwt_secret = "deardiary_secret"
    enable_auth = false
    cors_origins = ["*"]
    artifact_backend = "sqlite"
    artifact_fs_root = joinpath(pwd(), "deardiary_artifacts")
    artifact_s3_bucket = ""
    artifact_s3_endpoint = ""
    artifact_s3_region = "us-east-1"
    artifact_s3_access_key = ""
    artifact_s3_secret_key = ""
    enable_ui = true
    ui_host = "127.0.0.1"
    ui_port = 9001

    if (file |> isfile)
        env_vars = Dict{String,String}()

        for line in (file |> eachline)
            if !startswith(line, "#") && (line |> !isempty)
                key, value = split(line, "=", limit=2)
                env_vars[key] = value
            end
        end
        host = get(env_vars, "DEARDIARY_HOST", host)

        port = if haskey(env_vars, "DEARDIARY_PORT")
            parse(Int, env_vars["DEARDIARY_PORT"])
        else
            port
        end
        db_file = get(env_vars, "DEARDIARY_DB_FILE", db_file)
        jwt_secret = get(env_vars, "DEARDIARY_JWT_SECRET", jwt_secret)

        enable_auth = if haskey(env_vars, "DEARDIARY_ENABLE_AUTH")
            parse(Bool, env_vars["DEARDIARY_ENABLE_AUTH"])
        else
            enable_auth
        end

        cors_origins = if haskey(env_vars, "DEARDIARY_CORS_ORIGINS")
            split(env_vars["DEARDIARY_CORS_ORIGINS"], ',') .|> strip .|> string |> collect
        else
            cors_origins
        end

        artifact_backend = get(env_vars, "DEARDIARY_ARTIFACT_BACKEND", artifact_backend)
        artifact_fs_root = get(env_vars, "DEARDIARY_ARTIFACT_FS_ROOT", artifact_fs_root)
        artifact_s3_bucket = get(
            env_vars, "DEARDIARY_ARTIFACT_S3_BUCKET", artifact_s3_bucket,
        )
        artifact_s3_endpoint = get(
            env_vars, "DEARDIARY_ARTIFACT_S3_ENDPOINT", artifact_s3_endpoint,
        )
        artifact_s3_region = get(
            env_vars, "DEARDIARY_ARTIFACT_S3_REGION", artifact_s3_region,
        )
        artifact_s3_access_key = get(
            env_vars, "DEARDIARY_ARTIFACT_S3_ACCESS_KEY", artifact_s3_access_key,
        )
        artifact_s3_secret_key = get(
            env_vars, "DEARDIARY_ARTIFACT_S3_SECRET_KEY", artifact_s3_secret_key,
        )

        enable_ui = if haskey(env_vars, "DEARDIARY_ENABLE_UI")
            parse(Bool, env_vars["DEARDIARY_ENABLE_UI"])
        else
            enable_ui
        end
        ui_host = get(env_vars, "DEARDIARY_UI_HOST", ui_host)
        ui_port = if haskey(env_vars, "DEARDIARY_UI_PORT")
            parse(Int, env_vars["DEARDIARY_UI_PORT"])
        else
            ui_port
        end
    end
    return APIConfig(
        host, port, db_file, jwt_secret, enable_auth, cors_origins,
        artifact_backend, artifact_fs_root,
        artifact_s3_bucket, artifact_s3_endpoint, artifact_s3_region,
        artifact_s3_access_key, artifact_s3_secret_key,
        enable_ui, ui_host, ui_port,
    )
end
