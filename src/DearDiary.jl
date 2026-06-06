module DearDiary

using Oxygen: headers
using HTTP
using JSON
using JWTs
using Dates
using Bcrypt
using Bonito
using Compat
using Observables
using Oxygen
using LibGit2
using Pkg
using PrecompileTools: @setup_workload, @compile_workload
using SHA
using SQLite
using UUIDs

include("utils.jl")

include("types/config.jl")
include("types/enums.jl")
include("types/utils.jl")
include("types/error.jl")
include("types/user.jl")
include("types/project.jl")
include("types/userpermission.jl")
include("types/experiment.jl")
include("types/iteration.jl")
include("types/parameter.jl")
include("types/metric.jl")
include("types/resource.jl")
include("types/tag.jl")
include("types/model.jl")
include("types/modelversion.jl")

include("artifacts/store.jl")
include("artifacts/sqlite.jl")
include("artifacts/filesystem.jl")
include("artifacts/s3.jl")
include("artifacts/migrate.jl")

include("reproducibility/snapshot.jl")

include("repositories/sql/database.jl")
include("repositories/sql/user.jl")
include("repositories/sql/project.jl")
include("repositories/sql/userpermission.jl")
include("repositories/sql/experiment.jl")
include("repositories/sql/iteration.jl")
include("repositories/sql/parameter.jl")
include("repositories/sql/metric.jl")
include("repositories/sql/resource.jl")
include("repositories/sql/tag.jl")
include("repositories/sql/model.jl")
include("repositories/sql/modelversion.jl")
include("repositories/sql/migrations.jl")

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
include("repositories/tag.jl")
include("repositories/model.jl")
include("repositories/modelversion.jl")

include("services/utils.jl")
include("services/user.jl")
include("services/project.jl")
include("services/userpermission.jl")
include("services/experiment.jl")
include("services/iteration.jl")
include("reproducibility/restore.jl")
include("services/parameter.jl")
include("services/metric.jl")
include("services/resource.jl")
include("services/tag.jl")
include("services/model.jl")
include("services/modelversion.jl")

include("routes/utils.jl")
include("routes/user.jl")
include("routes/project.jl")
include("routes/userpermission.jl")
include("routes/experiment.jl")
include("routes/iteration.jl")
include("routes/parameter.jl")
include("routes/metric.jl")
include("routes/resource.jl")
include("routes/tag.jl")
include("routes/model.jl")
include("routes/modelversion.jl")
include("routes/auth.jl")

include("client/types.jl")
include("client/http.jl")
include("client/auth.jl")
include("client/user.jl")
include("client/project.jl")
include("client/userpermission.jl")
include("client/experiment.jl")
include("client/iteration.jl")
include("client/parameter.jl")
include("client/metric.jl")
include("client/resource.jl")
include("client/tag.jl")
include("client/model.jl")
include("client/modelversion.jl")
include("client/lifecycle.jl")

include("ui/app.jl")
include("ui/server.jl")

export Client, ClientError, connect, disconnect, refresh_token!, whoami, with_iteration

export get_user, get_users, create_user, update_user, delete_user, sanitize_user
export get_project, get_projects, create_project, update_project, delete_project
export get_userpermission, get_userpermissions, create_userpermission, update_userpermission, delete_userpermission
export get_experiment, get_experiments, create_experiment, update_experiment, delete_experiment
export get_iteration, get_iterations, create_iteration, update_iteration, delete_iteration
export get_child_iterations
export snapshot_environment!, capture_environment, restore
export EnvironmentSnapshot, RestoreResult
export get_parameter, get_parameters, create_parameter, update_parameter, delete_parameter
export get_metric, get_metrics, create_metric, update_metric, delete_metric, log_metrics
export get_resource, get_resources, create_resource, update_resource, delete_resource
export read_resource_data
export migrate_artifacts!, MigrateArtifactsResult
export get_tag, get_tags, create_tag, add_tag, delete_tag
export get_model, get_models, create_model, update_model, delete_model
export get_modelversion, get_modelversions, create_modelversion, update_modelversion, delete_modelversion

_DEARDIARY_APICONFIG = nothing

function AuthMiddleware(handler)
    return function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG

        if _DEARDIARY_APICONFIG.enable_auth
            is_login_route = request.target in ("/auth", "/auth/") &&
                             request.method == "POST"
            is_health_route = request.target |> startswith("/health") && request.method == "GET"

            if !(is_login_route || is_health_route)
                auth_header = get(request.headers |> Dict, "Authorization", missing)

                if auth_header |> ismissing
                    return error_response(
                        TokenMissing, "Missing authorization header";
                        status=HTTP.StatusCodes.UNAUTHORIZED,
                    )
                end

                token = split(auth_header, " ")[2] |> string
                jwt = JWT(; jwt=token)
                key = JWKSymmetric(
                    JWTs.MD_SHA256,
                    _DEARDIARY_APICONFIG.jwt_secret |> Array{UInt8,1},
                )
                try
                    validate!(jwt, key)
                catch _
                    return error_response(
                        TokenInvalid, "Invalid token";
                        status=HTTP.StatusCodes.UNAUTHORIZED,
                    )
                end

                if jwt |> isvalid
                    payload = jwt |> claims

                    if payload |> isnothing
                        return error_response(
                            TokenPayloadInvalid, "Invalid token payload";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end

                    is_valid_payload = all(
                        claim -> haskey(payload, claim),
                        ["sub", "id", "exp"],
                    )
                    if !is_valid_payload
                        return error_response(
                            TokenPayloadInvalid, "Invalid token payload";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end

                    exp = get(payload, "exp", nothing)
                    now_unix = (now() |> datetime2unix |> floor) |> Int
                    if exp |> isnothing || (exp isa Integer && exp < now_unix)
                        return error_response(
                            TokenExpired, "Token has expired";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end

                    user_id = get(payload, "id", 0)
                    is_valid_user_id = user_id isa Int && user_id > 0
                    if !is_valid_user_id
                        return error_response(
                            TokenPayloadInvalid, "Invalid token payload";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end

                    user = get_user(user_id)
                    if user |> isnothing
                        return error_response(
                            UserNotFound, "User not found";
                            status=HTTP.StatusCodes.UNAUTHORIZED,
                        )
                    end
                    request.context[:user] = user
                else
                    return error_response(
                        TokenInvalid, "Invalid token";
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
    global _DEARDIARY_APICONFIG = env_file |> load_config

    if _DEARDIARY_APICONFIG.enable_auth &&
       _DEARDIARY_APICONFIG.jwt_secret == "deardiary_secret"
        throw(
            ArgumentError(
                "Authentication is enabled but DEARDIARY_JWT_SECRET is set to the " *
                "built-in default. Set a strong, unique secret via the " *
                "DEARDIARY_JWT_SECRET environment variable before starting the server.",
            ),
        )
    end

    initialize_database(; file_name=_DEARDIARY_APICONFIG.db_file)

    @get "/health" function (::HTTP.Request)
        data = Dict(
            "app_name" => DearDiary |> nameof |> String,
            "package_version" => DearDiary |> pkgversion,
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
    setup_tag_routes()
    setup_model_routes()
    setup_modelversion_routes()
    setup_auth_routes()

    cors = Cors(;
        allowed_origins=_DEARDIARY_APICONFIG.cors_origins,
        allowed_headers=["Authorization", "Content-Type"],
        allowed_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_credentials=!("*" in _DEARDIARY_APICONFIG.cors_origins),
        max_age=600,
    )
    serveparallel(;
        host=_DEARDIARY_APICONFIG.host,
        port=_DEARDIARY_APICONFIG.port,
        async=true,
        middleware=[cors, AuthMiddleware],
    )
    @info "DearDiary server running on $(_DEARDIARY_APICONFIG.host):$(_DEARDIARY_APICONFIG.port)"

    if _DEARDIARY_APICONFIG.enable_ui
        global _DEARDIARY_UI_SERVER = start_ui_server(
            _DEARDIARY_APICONFIG.ui_host, _DEARDIARY_APICONFIG.ui_port,
        )
    end
end

"""
    stop()

Stops the server. Alias for `Oxygen.Core.terminate()`.
"""
function stop()
    global _DEARDIARY_UI_SERVER
    stop_ui_server(_DEARDIARY_UI_SERVER)
    _DEARDIARY_UI_SERVER = nothing

    close_database()
    _DEARDIARY_APICONFIG = nothing

    terminate()
    @info "DearDiary server stopped."
end

# Precompile workload: bake the cold-start cost into `Pkg.precompile` rather than the
# first browser request. The workload exercises the render paths a user's first browser
# request hits: service-layer queries, sidebar/detail Hyperscript construction, and the
# Plotly trace JSON encoder.
@setup_workload begin
    _warm_dir = mktempdir()
    _warm_db = joinpath(_warm_dir, "deardiary_precompile.db")
    try
        @compile_workload begin
            initialize_database(; file_name=_warm_db)
            user = "default" |> get_user
            project_id, _ = create_project(user.id, "warmup")
            experiment_id, _ = create_experiment(
                project_id, IN_PROGRESS, "warmup experiment",
            )

            # One driver iteration with parameters + metrics across multiple steps,
            # plus one child trial so the sidebar's nested-tree branch compiles.
            driver_id, _ = create_iteration(experiment_id)
            create_parameter(driver_id, "alpha", 0.1)
            create_parameter(driver_id, "epochs", 3)
            for step in 1:3
                create_metric(driver_id, "loss", 1.0 / step; step=step)
                create_metric(driver_id, "accuracy", 0.5 + 0.1 * step; step=step)
            end
            update_iteration(driver_id, nothing, now(), SUCCEEDED)

            child_id, _ = create_iteration(
                experiment_id; parent_iteration_id=driver_id,
            )
            create_parameter(child_id, "max_depth", 4)
            update_iteration(child_id, nothing, now(), SUCCEEDED)

            # Warm the rendering functions for both the empty-state and populated-state
            # branches that user requests hit on first navigation.
            _render_iteration_detail(nothing)
            _render_iteration_detail(driver_id)
            _render_iteration_detail(child_id)
            _iteration_title(nothing)
            _iteration_title(driver_id)
            _iteration_title(-1)

            # Warm the sidebar label helpers across every status branch and a few
            # representative time-delta ranges so the cold path stays trivial.
            for status in (RUNNING, SUCCEEDED, FAILED, KILLED)
                _status_glyph(status |> Integer)
            end
            _ref = now()
            _relative_time(_ref - Second(5), _ref)
            _relative_time(_ref - Minute(30), _ref)
            _relative_time(_ref - Hour(2), _ref)
            _relative_time(_ref - Day(3), _ref)
            _relative_time(_ref - Day(120), _ref)
            _relative_time(_ref - Day(500), _ref)

            _selected = Observables.Observable{Optional{Int64}}(nothing)
            _render_sidebar(user, _selected)

            # Round-trip the metrics-chart JSON encoder so the cache holds `JSON.json`
            # for `Vector{Dict{…}}`.
            _build_metrics_figure(driver_id |> get_metrics)

            # Exercise the full Bonito render pipeline (Session bootstrap, DOM walking,
            # Hyperscript serialization, asset registration) by rendering the App to
            # static HTML on disk. With this branch removed the cold-start cost lives in
            # Bonito's downstream codepaths that the `_render_*` functions never reach.
            # A live `Bonito.Server` inside `@compile_workload` would warm even more code,
            # but it leaves a TCP handle dangling that blocks precompilation.
            try
                _warm_app = build_ui_app()
                _warm_export = joinpath(_warm_dir, "export")
                mkpath(_warm_export)
                Bonito.export_static(_warm_export, Bonito.Routes("/" => _warm_app))
            catch _
                # Static export is best-effort during precompile; the rendering-function
                # warmup above carries most of the win even when Bonito's asset bundler
                # cannot reach network or disk in a build sandbox.
            end

            close_database()
        end
    finally
        rm(_warm_dir; recursive=true, force=true)
    end
end

end
