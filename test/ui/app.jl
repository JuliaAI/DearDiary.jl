# Builds an `Iteration` row without touching the database, for the pure helpers.
function _ui_iteration(id, parent, second; status=DearDiary.RUNNING)
    return DearDiary.Iteration(
        id,
        "experiment",
        "",
        DateTime(2026, 1, 1, 0, 0, second),
        nothing,
        parent,
        Integer(status),
        "",
        "",
        "",
        false,
        "",
        "",
        "",
    )
end

_ui_context(method, target) = (request=HTTP.Request(method, target),)

# The dashboard reads the server config to decide whether sessions are required. These
# tests cover the auth-off behaviour, so start from no config whatever ran before.
DearDiary.eval(:(global _DEARDIARY_APICONFIG = nothing))

@testset verbose = true "ui/app" begin
    @testset "_format_duration formats across the unit ladder" begin
        @test DearDiary._format_duration(Dates.Millisecond(500)) == "500 ms"
        @test DearDiary._format_duration(Dates.Millisecond(1060)) == "1.06s"
        @test DearDiary._format_duration(Dates.Millisecond(90000)) == "1m 30s"
        @test DearDiary._format_duration(Dates.Millisecond(3_660_000)) == "1h 1m"
        @test DearDiary._format_duration(Dates.Millisecond(-5)) == "–"
    end

    @testset "_relative_time formats deltas across the unit ladder" begin
        ref = DateTime(2026, 6, 5, 12, 0, 0)
        @test DearDiary._relative_time(ref - Dates.Second(30), ref) == "just now"
        @test DearDiary._relative_time(ref - Dates.Minute(5), ref) == "5m ago"
        @test DearDiary._relative_time(ref - Dates.Hour(2), ref) == "2h ago"
        @test DearDiary._relative_time(ref - Dates.Day(3), ref) == "3d ago"
        @test DearDiary._relative_time(DateTime(2026, 3, 5, 9, 0, 0), ref) == "Mar 5"
        @test DearDiary._relative_time(DateTime(2025, 11, 1, 9, 0, 0), ref) == "Nov 1, 2025"
        # Clock-skew safety: future timestamps collapse to "just now".
        @test DearDiary._relative_time(ref + Dates.Hour(1), ref) == "just now"
    end

    @testset "_format_number keeps four significant digits" begin
        @test DearDiary._format_number(1.0) == "1"
        @test DearDiary._format_number(0.5) == "0.5"
        @test DearDiary._format_number(2 / 3) == "0.6667"
        @test DearDiary._format_number(0) == "0"
        @test DearDiary._format_number(1234.5678) == "1235"
        @test DearDiary._format_number(1_000_000) == "1.0e6"
        @test DearDiary._format_number(1.5e7) == "1.5e7"
        @test DearDiary._format_number(0.00001234) == "1.234e-5"
        @test DearDiary._format_number(NaN) == "NaN"
        @test DearDiary._format_number(Inf) == "Inf"
        @test DearDiary._format_number(-Inf) == "-Inf"
    end

    @testset "small formatting helpers" begin
        @test DearDiary._format_bytes(512) == "512 B"
        @test DearDiary._format_bytes(2048) == "2.0 KB"
        @test DearDiary._format_bytes(150_000) == "146 KB"
        @test DearDiary._format_bytes(5 * 1024^3) == "5.0 GB"
        @test DearDiary._short_sha("abcdef1234567") == "abcdef1"
        @test DearDiary._short_sha("abc") == "abc"
        @test DearDiary._pluralize(1, "step") == "1 step"
        @test DearDiary._pluralize(3, "step") == "3 steps"
        @test DearDiary._truncate("hello world", 5) == "hell…"
        @test DearDiary._truncate("hi", 5) == "hi"
        @test DearDiary._line_count("") == 0
        @test DearDiary._line_count("a\nb") == 2
        @test DearDiary._line_count("a\nb\n") == 2
        @test DearDiary._project_url("p") == "/project/p"
        @test DearDiary._experiment_url("e") == "/experiment/e"
        @test DearDiary._iteration_url("i") == "/iteration/i"
        @test DearDiary._model_url("m") == "/model/m"
        @test DearDiary._download_url("r") == "/resource/r/download"
        @test DearDiary._safe_filename("model (v2).jlso") == "model _v2_.jlso"
        @test DearDiary._safe_filename("\"/\\") == "___"
        @test DearDiary._safe_filename("") == "artifact"
    end

    @testset "status chrome maps every enum value" begin
        @test DearDiary._iteration_status(Integer(DearDiary.RUNNING)).label == "running"
        @test DearDiary._iteration_status(Integer(DearDiary.SUCCEEDED)).tone == "sage"
        @test DearDiary._iteration_status(Integer(DearDiary.FAILED)).tone == "brick"
        @test DearDiary._iteration_status(Integer(DearDiary.KILLED)).tone == "plum"
        @test DearDiary._iteration_status(999).label == "unknown"
        @test DearDiary._experiment_status(Integer(DearDiary.IN_PROGRESS)).label ==
            "in progress"
        @test DearDiary._experiment_status(Integer(DearDiary.FINISHED)).tone == "sage"
        @test DearDiary._experiment_status(Integer(DearDiary.STOPPED)).tone == "plum"
        @test DearDiary._stage(Integer(DearDiary.PRODUCTION)).label == "production"
        @test DearDiary._stage(Integer(DearDiary.STAGING)).tone == "ochre"
        @test DearDiary._stage(Integer(DearDiary.ARCHIVED)).tone == "plum"
        @test DearDiary._stage(Integer(DearDiary.NO_STAGE)).label == "no stage"
    end

    @testset "_tree_order nests children after parents and keeps orphans" begin
        rows = [
            _ui_iteration("c", "a", 3),
            _ui_iteration("a", nothing, 1),
            _ui_iteration("orphan", "gone", 4),
            _ui_iteration("b", nothing, 2),
            _ui_iteration("d", "c", 5),
        ]
        ordered = DearDiary._tree_order(rows)
        @test [it.id for (it, _) in ordered] == ["a", "c", "d", "b", "orphan"]
        @test [depth for (_, depth) in ordered] == [0, 1, 2, 0, 0]
        @test DearDiary._ordinals(rows) ==
            Dict("a" => 1, "b" => 2, "c" => 3, "orphan" => 4, "d" => 5)
    end

    @testset "_status_counts and _last_activity" begin
        rows = [
            _ui_iteration("a", nothing, 1; status=DearDiary.SUCCEEDED),
            _ui_iteration("b", nothing, 2; status=DearDiary.SUCCEEDED),
            _ui_iteration("c", nothing, 3; status=DearDiary.FAILED),
        ]
        counts = DearDiary._status_counts(rows)
        @test DearDiary._count(counts, DearDiary.SUCCEEDED) == 2
        @test DearDiary._count(counts, DearDiary.FAILED) == 1
        @test DearDiary._count(counts, DearDiary.KILLED) == 0
        @test DearDiary._last_activity(rows) == DateTime(2026, 1, 1, 0, 0, 3)
        @test DearDiary._last_activity(DearDiary.Iteration[]) === nothing
    end

    @testset "chart payloads are valid JSON with nulls for non-finite values" begin
        @test DearDiary._series_color(1) == "#4a7aa6"
        @test DearDiary._series_color(11) == "#4a7aa6"
        series = [
            DearDiary._chart_series("loss", "#000000", [(1, 0.5), (2, NaN), (3, Inf)])
        ]
        payload = DearDiary._chart_payload("loss", series; legend=true)
        spec = JSON.parse(payload)
        @test spec["title"] == "loss"
        @test spec["type"] == "line"
        @test spec["legend"] == true
        @test spec["series"][1]["points"] == [[1, 0.5], [2, nothing], [3, nothing]]
        scatter = JSON.parse(
            DearDiary._chart_payload(
                "acc",
                [
                    DearDiary._chart_series(
                        "acc", "#000", [(1, 0.9)]; labels=["Iteration 1"]
                    ),
                ];
                type="scatter",
                xprefix="#",
            ),
        )
        @test scatter["xprefix"] == "#"
        @test scatter["series"][1]["points"] == [[1, 0.9, "Iteration 1"]]
    end

    @testset "metric summaries and per-iteration rows" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "RowsProject")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "RowsExp"
            )
            parent_id, _ = DearDiary.create_iteration(experiment_id)
            child_id, _ = DearDiary.create_iteration(
                experiment_id; parent_iteration_id=parent_id
            )
            DearDiary.create_parameter(parent_id, "depth", 4)
            DearDiary.create_parameter(child_id, "depth", 8)
            for step in 1:3
                DearDiary.create_metric(parent_id, "loss", 1.0 / step; step=step)
            end
            DearDiary.create_metric(child_id, "accuracy", 0.9)
            DearDiary.add_tag(DearDiary.Iteration, child_id, "trial")

            summaries = DearDiary._metric_summaries(DearDiary.get_metrics(parent_id))
            @test length(summaries) == 1
            @test summaries[1].key == "loss"
            @test summaries[1].count == 3
            @test summaries[1].last == 1 / 3
            @test summaries[1].last_step == 3
            @test summaries[1].min == 1 / 3
            @test summaries[1].max == 1.0

            rows = DearDiary._iteration_rows(DearDiary.get_iterations(experiment_id))
            @test [r.ordinal for r in rows] == [1, 2]
            @test [r.depth for r in rows] == [0, 1]
            @test rows[2].parent_ordinal == 1
            @test rows[1].parameters == Dict("depth" => "4")
            @test DearDiary._parameter_keys(rows) == ["depth"]
            @test DearDiary._metric_keys(rows) == ["accuracy", "loss"]
            @test DearDiary._final_value(rows[1], "loss") == 1 / 3
            @test DearDiary._final_value(rows[1], "accuracy") === nothing
            @test [t.value for t in rows[2].tags] == ["trial"]

            charts = DearDiary._experiment_charts(rows)
            @test length(charts) == 2
            iteration_charts = DearDiary._iteration_charts(DearDiary.get_metrics(parent_id))
            @test length(iteration_charts) == 1
            @test isempty(DearDiary._iteration_charts(DearDiary.get_metrics(child_id)))
        end
    end

    @testset "_can_read follows admin status and project permissions" begin
        @with_deardiary_test_db begin
            admin = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(admin.id, "PermProject")
            user_id, _ = DearDiary.create_user("Ada", "Lovelace", "ada", "secret-pw")
            ada = DearDiary.get_user(user_id)

            @test DearDiary._can_read(admin, project_id)
            @test !DearDiary._can_read(ada, project_id)
            @test !DearDiary._can_read(admin, nothing)
            DearDiary.create_userpermission(user_id, project_id, false, true, false, false)
            @test DearDiary._can_read(ada, project_id)
        end
    end

    @testset "render_page: empty store shows the welcome block" begin
        @with_deardiary_test_db begin
            status, html = DearDiary.render_page("/")
            @test status == 200
            @test startswith(html, "<!DOCTYPE html>")
            @test occursin("<title>Projects · DearDiary</title>", html)
            @test occursin("charset=\"UTF-8\"", html)
            @test occursin("A blank notebook.", html)
            @test occursin("DearDiary.connect", html)
            @test occursin("dd-topbar", html)
            @test occursin("juliaai.github.io/DearDiary.jl/dev/", html)
            # Stylesheet and script are inlined; nothing is fetched from a CDN.
            @test occursin("JuliaMono", html)
            @test occursin("data-theme-toggle", html)
            @test !occursin("cdn.", html)
            @test !occursin("<script src=", html)
        end
    end

    @testset "render_page: every entity page renders" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Iris classifier")
            DearDiary.update_project(project_id, nothing, "Species classification.")
            DearDiary.add_tag(DearDiary.Project, project_id, "tabular")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Forest sweep"
            )
            DearDiary.add_tag(DearDiary.Experiment, experiment_id, "hpo")
            parent_id, _ = DearDiary.create_iteration(experiment_id)
            child_id, _ = DearDiary.create_iteration(
                experiment_id; parent_iteration_id=parent_id
            )
            failed_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.create_parameter(parent_id, "max_depth", 8)
            for step in 1:4
                DearDiary.create_metric(parent_id, "loss", 1.0 / step; step=step)
            end
            DearDiary.create_metric(parent_id, "accuracy", 0.95)
            DearDiary.add_tag(DearDiary.Iteration, parent_id, "baseline")
            DearDiary.update_iteration(
                parent_id, "Driver run notes.", now(), DearDiary.SUCCEEDED
            )
            DearDiary.update_iteration(
                failed_id, nothing, now(), DearDiary.FAILED; error_message="Boom at step 3"
            )
            DearDiary.update(
                DearDiary.Iteration,
                parent_id;
                julia_version="1.11.0",
                git_sha="abc1234",
                git_dirty=1,
                entrypoint="train.jl",
                project_toml="[deps]\n",
                manifest_toml="# manifest\n",
            )
            resource_id, _ = DearDiary.create_resource(
                experiment_id, "weights.bin", UInt8[1, 2, 3]
            )
            model_id, _ = DearDiary.create_model(project_id, "iris-forest")
            version_id, _ = DearDiary.create_modelversion(
                model_id, parent_id, resource_id, "first cut"
            )
            DearDiary.update_modelversion(
                version_id, DearDiary.PRODUCTION, nothing, nothing
            )

            status, home = DearDiary.render_page("/")
            @test status == 200
            @test occursin("Iris classifier", home)
            @test occursin("Species classification.", home)
            @test occursin("#tabular", home) || occursin(">tabular<", home)
            @test occursin("/project/$(project_id)", home)

            status, project = DearDiary.render_page("/project/$(project_id)")
            @test status == 200
            @test occursin("<title>Iris classifier · DearDiary</title>", project)
            @test occursin("Forest sweep", project)
            @test occursin("/experiment/$(experiment_id)", project)
            @test occursin("dd-statusbar", project)
            @test occursin("iris-forest", project)
            @test occursin("/model/$(model_id)", project)
            @test occursin("production", project)

            status, experiment = DearDiary.render_page("/experiment/$(experiment_id)")
            @test status == 200
            @test occursin("<title>Forest sweep · DearDiary</title>", experiment)
            @test occursin("#1", experiment)
            @test occursin("child of #1", experiment)
            @test occursin("dd-row-child", experiment)
            @test occursin("max_depth", experiment)
            @test occursin(">loss<", experiment)
            @test occursin("data-chart=", experiment)
            @test occursin("data-sortable", experiment)
            @test occursin("weights.bin", experiment)
            @test occursin("/resource/$(resource_id)/download", experiment)
            @test occursin("failed", experiment)
            # The child iteration is still running, so the page keeps itself fresh.
            @test occursin("data-live=\"15\"", experiment)

            status, iteration = DearDiary.render_page("/iteration/$(parent_id)")
            @test status == 200
            @test occursin(
                "<title>Iteration 1 · Forest sweep · DearDiary</title>", iteration
            )
            @test occursin("Driver run notes.", iteration)
            @test occursin("baseline", iteration)
            @test occursin("max_depth", iteration)
            @test occursin("data-spark=", iteration)
            @test occursin("1.11.0", iteration)
            @test occursin("abc1234", iteration)
            @test occursin("dirty tree", iteration)
            @test occursin("train.jl", iteration)
            @test occursin("Manifest.toml", iteration)
            # Hyperscript escapes quotes and parentheses in text nodes; browsers decode them.
            @test occursin("DearDiary.restore&#40;&#34;$(parent_id)&#34;&#41;", iteration)
            @test occursin("Lineage", iteration)
            @test occursin("/iteration/$(child_id)", iteration)
            @test occursin("Model registry", iteration)
            @test occursin("/model/$(model_id)", iteration)

            status, child = DearDiary.render_page("/iteration/$(child_id)")
            @test status == 200
            @test occursin("No environment captured.", child)
            @test occursin("No parameters recorded.", child)
            @test occursin("No metrics recorded.", child)
            @test occursin("/iteration/$(parent_id)", child)
            # A running iteration asks the browser to keep the page fresh.
            @test occursin("data-live=\"15\"", child)
            @test occursin("Refreshing in", child)

            status, failed = DearDiary.render_page("/iteration/$(failed_id)")
            @test status == 200
            @test occursin("Boom at step 3", failed)
            @test occursin("dd-note--error", failed)

            status, model = DearDiary.render_page("/model/$(model_id)")
            @test status == 200
            @test occursin("<title>iris-forest · DearDiary</title>", model)
            @test occursin("v1", model)
            @test occursin("production", model)
            @test occursin("first cut", model)
            @test occursin("weights.bin", model)
            @test occursin("/iteration/$(parent_id)", model)
        end
    end

    @testset "render_page: unknown ids and paths return the not-found page" begin
        @with_deardiary_test_db begin
            for path in (
                "/iteration/00000000-0000-0000-0000-000000000000",
                "/project/nope",
                "/experiment/nope",
                "/model/nope",
                "/nothing/here",
            )
                status, html = DearDiary.render_page(path)
                @test status == 404
                @test occursin("<title>Not found · DearDiary</title>", html)
                @test occursin("Back to projects", html)
            end
        end
    end

    @testset "HTTP handlers" begin
        @with_deardiary_test_db begin
            page = DearDiary._handle_page(_ui_context("GET", "/?utm=1"))
            @test page.status == 200
            @test HTTP.header(page, "Content-Type") == "text/html; charset=utf-8"
            @test occursin("<!DOCTYPE html>", String(page.body))

            missing = DearDiary._handle_page(_ui_context("GET", "/iteration/nope"))
            @test missing.status == 404

            font = DearDiary._handle_static(
                _ui_context("GET", "/static/fonts/juliamono-regular.woff2")
            )
            @test font.status == 200
            @test HTTP.header(font, "Content-Type") == "font/woff2"
            @test !isempty(font.body)
            logo = DearDiary._handle_static(_ui_context("GET", "/static/logo.svg"))
            @test logo.status == 200
            @test HTTP.header(logo, "Content-Type") == "image/svg+xml"
            @test DearDiary._handle_static(
                _ui_context("GET", "/static/../Project.toml")
            ).status == 404
            @test DearDiary._handle_static(_ui_context("GET", "/static/nope.css")).status ==
                404

            favicon = DearDiary._serve_favicon_ico(nothing)
            @test favicon.status == 200
            @test HTTP.header(favicon, "Content-Type") == "image/svg+xml"
            @test favicon.body == read(joinpath(pkgdir(DearDiary), "assets", "logo.svg"))

            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "DownloadProject")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "DownloadExp"
            )
            bytes = UInt8[0x44, 0x44, 0x00, 0xff]
            resource_id, _ = DearDiary.create_resource(
                experiment_id, "model (v2).jlso", bytes
            )
            download = DearDiary._handle_download(
                _ui_context("GET", "/resource/$(resource_id)/download")
            )
            @test download.status == 200
            @test download.body == bytes
            @test HTTP.header(download, "Content-Type") == "application/octet-stream"
            @test HTTP.header(download, "Content-Disposition") ==
                "attachment; filename=\"model _v2_.jlso\""
            @test DearDiary._handle_download(
                _ui_context("GET", "/resource/nope/download")
            ).status == 404
            @test DearDiary._handle_download(_ui_context("GET", "/resource/")).status == 404
        end
    end
end

# Builds a form post the way a browser would, carrying the session's CSRF token.
function _ui_post(path, fields::AbstractDict; csrf=true)
    request = HTTP.Request(
        "POST", path, ["Content-Type" => "application/x-www-form-urlencoded"], ""
    )
    pairs = ["$(HTTP.URIs.escapeuri(k))=$(HTTP.URIs.escapeuri(v))" for (k, v) in fields]
    csrf && push!(pairs, "csrf=$(DearDiary._csrf_token(request))")
    request.body = Vector{UInt8}(join(pairs, "&"))
    return request
end

_ui_location(response) = HTTP.header(response, "Location")

@testset verbose = true "ui/users" begin
    @testset "session helpers with authentication off" begin
        request = HTTP.Request("GET", "/", ["Cookie" => "a=1; dd_session=tok; b=2"])
        @test DearDiary._cookies(request) ==
            Dict("a" => "1", "dd_session" => "tok", "b" => "2")
        @test DearDiary._session_token(request) == "tok"
        @test DearDiary._session_token(HTTP.Request("GET", "/")) === nothing
        @test !DearDiary._auth_enabled()
        @test DearDiary._safe_next(nothing) == "/"
        @test DearDiary._safe_next("//evil.example") == "/"
        @test DearDiary._safe_next("https://evil.example") == "/"
        @test DearDiary._safe_next("/project/abc") == "/project/abc"
        @test DearDiary._login_url("/") == "/login"
        @test DearDiary._login_url("/project/a b") == "/login?next=%2Fproject%2Fa%20b"
        @test DearDiary._form_fields(
            _ui_post("/x", Dict("first_name" => "Ada L", "x" => "a&b"); csrf=false)
        ) == Dict("first_name" => "Ada L", "x" => "a&b")
        plain = HTTP.Request("GET", "/")
        @test length(DearDiary._csrf_token(plain)) == 32
        @test DearDiary._post_allowed(plain, Dict("csrf" => DearDiary._csrf_token(plain)))
        @test !DearDiary._post_allowed(plain, Dict("csrf" => "nope"))
        cross = HTTP.Request("POST", "/", ["Sec-Fetch-Site" => "cross-site"])
        @test !DearDiary._post_allowed(cross, Dict("csrf" => DearDiary._csrf_token(cross)))
        @with_deardiary_test_db begin
            @test DearDiary._session_user(plain).username == "default"
            @test DearDiary._handle_login((
                request=HTTP.Request("GET", "/login"),
            )).status == 303
            @test DearDiary._handle_logout((
                request=HTTP.Request("GET", "/logout"),
            )).status == 303
        end
    end

    @testset "users pages render for admins and members" begin
        @with_deardiary_test_db begin
            admin = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(admin.id, "Visible")
            hidden_id, _ = DearDiary.create_project(admin.id, "Hidden")
            alice_id, _ = DearDiary.create_user("Ada", "Lovelace", "alice", "wonderland")
            DearDiary.create_userpermission(alice_id, project_id, false, true, false, false)
            alice = DearDiary.get_user(alice_id)
            as_admin(path; query=Dict{String,String}()) = DearDiary.render_page(
                path, DearDiary.PageContext(admin; path=path, csrf="tok", query=query)
            )
            as_alice(path) = DearDiary.render_page(
                path, DearDiary.PageContext(alice; path=path, csrf="tok")
            )

            status, users = as_admin("/users")
            @test status == 200
            @test occursin("<title>Users · DearDiary</title>", users)
            @test occursin("alice", users)
            @test occursin("1 of 2", users)
            @test occursin("all projects", users)
            @test occursin("action=\"/users\"", users)
            @test occursin("name=\"csrf\" value=\"tok\"", users) ||
                occursin("value=\"tok\" name=\"csrf\"", users)
            @test occursin("href=\"/users\"", users)

            status, page = as_admin("/users/$(alice_id)"; query=Dict("ok" => "created"))
            @test status == 200
            @test occursin("User created.", page)
            @test occursin("dd-banner--ok", page)
            @test occursin("action=\"/users/$(alice_id)/profile\"", page)
            @test occursin("action=\"/users/$(alice_id)/password\"", page)
            @test occursin("action=\"/users/$(alice_id)/role\"", page)
            @test occursin("action=\"/users/$(alice_id)/permissions\"", page)
            @test occursin("action=\"/users/$(alice_id)/delete\"", page)
            @test occursin("perm:$(project_id):read", page)
            @test occursin("perm:$(hidden_id):read", page)

            status, settings = as_admin("/settings")
            @test status == 200
            @test occursin("<title>Settings · DearDiary</title>", settings)
            @test occursin("Your account", settings)
            @test occursin("always stays an administrator", settings)
            @test !occursin("/delete\"", settings)

            status, forbidden = as_alice("/users")
            @test status == 403
            @test occursin("Administrators only", forbidden)
            status, _ = as_alice("/users/$(admin.id)")
            @test status == 403
            status, own = as_alice("/settings")
            @test status == 200
            @test occursin("/users/$(alice_id)/password", own)
            @test !occursin("/users/$(alice_id)/role", own)
            @test !occursin("href=\"/users\"", own)

            status, home = as_alice("/")
            @test status == 200
            @test occursin("Visible", home)
            @test !occursin("Hidden", home)
            status, _ = as_alice("/project/$(hidden_id)")
            @test status == 404
            status, _ = as_alice("/project/$(project_id)")
            @test status == 200
            status, _ = as_admin("/users/00000000-0000-0000-0000-000000000000")
            @test status == 404
        end
    end

    @testset "user-management posts" begin
        @with_deardiary_test_db begin
            admin = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(admin.id, "Posts")
            ctx(viewer, path) = DearDiary.PageContext(
                viewer; path=path, csrf=DearDiary._csrf_token(HTTP.Request("GET", "/"))
            )

            missing_token = DearDiary._handle_users_post(
                ctx(admin, "/users"),
                _ui_post("/users", Dict("username" => "x", "password" => "y"); csrf=false),
            )
            @test missing_token.status == 303
            @test _ui_location(missing_token) == "/users?err=csrf"

            created = DearDiary._handle_users_post(
                ctx(admin, "/users"),
                _ui_post(
                    "/users",
                    Dict(
                        "first_name" => "Ada",
                        "last_name" => "Lovelace",
                        "username" => "alice",
                        "password" => "wonderland",
                        "is_admin" => "on",
                    ),
                ),
            )
            @test created.status == 303
            alice = DearDiary.get_user_by_username("alice")
            @test !isnothing(alice)
            @test alice.is_admin
            @test _ui_location(created) == "/users/$(alice.id)?ok=created"

            duplicate = DearDiary._handle_users_post(
                ctx(admin, "/users"),
                _ui_post("/users", Dict("username" => "alice", "password" => "x")),
            )
            @test _ui_location(duplicate) == "/users?err=duplicate"
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(admin, "/users"),
                    _ui_post("/users", Dict("username" => "", "password" => "x")),
                ),
            ) == "/users?err=username"
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(admin, "/users"),
                    _ui_post("/users", Dict("username" => "bob", "password" => "")),
                ),
            ) == "/users?err=password_empty"
            member_id, _ = DearDiary.create_user("Member", "Only", "member", "pw")
            member = DearDiary.get_user(member_id)
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(member, "/users"),
                    _ui_post("/users", Dict("username" => "bob", "password" => "pw")),
                ),
            ) == "/?err=forbidden"

            base = "/users/$(alice.id)"
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(admin, base * "/role"),
                    _ui_post(base * "/role", Dict{String,String}()),
                ),
            ) == "$(base)?ok=role"
            alice = DearDiary.get_user(alice.id)
            @test !alice.is_admin

            profile = DearDiary._handle_users_post(
                ctx(alice, base * "/profile"),
                _ui_post(
                    base * "/profile",
                    Dict("first_name" => "Augusta", "last_name" => "King"),
                ),
            )
            @test _ui_location(profile) == "$(base)?ok=profile"
            @test DearDiary.get_user(alice.id).first_name == "Augusta"

            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(alice, base * "/password"),
                    _ui_post(
                        base * "/password",
                        Dict("password" => "a", "password_confirm" => "b"),
                    ),
                ),
            ) == "$(base)?err=password_mismatch"
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(alice, base * "/password"),
                    _ui_post(
                        base * "/password", Dict("password" => "", "password_confirm" => "")
                    ),
                ),
            ) == "$(base)?err=password_empty"
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(alice, base * "/password"),
                    _ui_post(
                        base * "/password",
                        Dict(
                            "password" => "new-secret", "password_confirm" => "new-secret"
                        ),
                    ),
                ),
            ) == "$(base)?ok=password"
            @test CompareHashAndPassword(
                DearDiary.get_user(alice.id).password, "new-secret"
            )

            # Members cannot touch roles, access, or other accounts.
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(alice, base * "/role"),
                    _ui_post(base * "/role", Dict("is_admin" => "on")),
                ),
            ) == "$(base)?err=forbidden"
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(alice, "/users/$(admin.id)/profile"),
                    _ui_post("/users/$(admin.id)/profile", Dict("first_name" => "x")),
                ),
            ) == "/?err=forbidden"

            perms = DearDiary._handle_users_post(
                ctx(admin, base * "/permissions"),
                _ui_post(
                    base * "/permissions",
                    Dict(
                        "perm:$(project_id):read" => "on",
                        "perm:$(project_id):update" => "on",
                    ),
                ),
            )
            @test _ui_location(perms) == "$(base)?ok=permissions"
            granted = DearDiary.get_userpermission(alice.id, project_id)
            @test granted.read_permission &&
                granted.update_permission &&
                !granted.create_permission
            DearDiary._handle_users_post(
                ctx(admin, base * "/permissions"),
                _ui_post(base * "/permissions", Dict("perm:$(project_id):create" => "on")),
            )
            granted = DearDiary.get_userpermission(alice.id, project_id)
            @test granted.create_permission && !granted.read_permission
            DearDiary._handle_users_post(
                ctx(admin, base * "/permissions"),
                _ui_post(base * "/permissions", Dict{String,String}()),
            )
            @test DearDiary.get_userpermission(alice.id, project_id) === nothing

            admin_base = "/users/$(admin.id)"
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(admin, admin_base * "/role"),
                    _ui_post(admin_base * "/role", Dict{String,String}()),
                ),
            ) == "$(admin_base)?err=self"
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(admin, admin_base * "/delete"),
                    _ui_post(admin_base * "/delete", Dict{String,String}()),
                ),
            ) == "$(admin_base)?err=self"
            # Promote alice so she can try to demote or delete the seeded account.
            DearDiary.update_user(alice.id, nothing, nothing, nothing, true)
            alice = DearDiary.get_user(alice.id)
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(alice, admin_base * "/role"),
                    _ui_post(admin_base * "/role", Dict{String,String}()),
                ),
            ) == "$(admin_base)?err=default_user"
            @test _ui_location(
                DearDiary._handle_users_post(
                    ctx(alice, admin_base * "/delete"),
                    _ui_post(admin_base * "/delete", Dict{String,String}()),
                ),
            ) == "$(admin_base)?err=default_user"
            @test DearDiary.get_user_by_username("default").is_admin

            deleted = DearDiary._handle_users_post(
                ctx(admin, base * "/delete"),
                _ui_post(base * "/delete", Dict{String,String}()),
            )
            @test _ui_location(deleted) == "/users?ok=deleted"
            @test DearDiary.get_user(alice.id) === nothing
            @test DearDiary._handle_users_post(
                ctx(admin, base * "/delete"),
                _ui_post(base * "/delete", Dict{String,String}()),
            ).status == 404

            page = DearDiary._handle_page((
                request=_ui_post("/users", Dict("username" => "carol", "password" => "pw")),
            ))
            @test page.status == 303
            @test startswith(_ui_location(page), "/users/")
            @test DearDiary._handle_page((
                request=_ui_post("/project/x", Dict{String,String}()),
            )).status == 405
        end
    end
end

@testset verbose = true "ui/edits" begin
    @testset "inline editors and the actions menu follow project permissions" begin
        @with_deardiary_test_db begin
            admin = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(admin.id, "Editable")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Sweep"
            )
            running_id, _ = DearDiary.create_iteration(experiment_id)
            ended_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.update_iteration(ended_id, nothing, now(), DearDiary.SUCCEEDED)
            model_id, _ = DearDiary.create_model(project_id, "forest")
            version_id, _ = DearDiary.create_modelversion(model_id, ended_id, nothing, "v")
            reader_id, _ = DearDiary.create_user("Read", "Only", "reader", "pw")
            DearDiary.create_userpermission(
                reader_id, project_id, false, true, false, false
            )
            editor_id, _ = DearDiary.create_user("Edit", "Only", "editor", "pw")
            DearDiary.create_userpermission(editor_id, project_id, true, true, true, false)
            reader = DearDiary.get_user(reader_id)
            editor = DearDiary.get_user(editor_id)
            page(viewer, path) = DearDiary.render_page(
                path, DearDiary.PageContext(viewer; path=path, csrf="tok")
            )[2]

            project = page(admin, "/project/$(project_id)")
            @test occursin("data-inline-open=\"#edit-name\"", project)
            @test occursin("data-inline-open=\"#edit-description\"", project)
            @test occursin("action=\"/project/$(project_id)/edit\"", project)
            @test occursin("data-inline-open=\"#tag-add\"", project)
            @test occursin("action=\"/project/$(project_id)/tags\"", project)
            @test occursin("class=\"dd-menu\"", project)
            @test occursin("action=\"/project/$(project_id)/delete\"", project)
            @test occursin("data-confirm=", project)
            # Members never edit projects, but create permission still lets them tag.
            member_project = page(editor, "/project/$(project_id)")
            @test !occursin("#edit-name", member_project)
            @test !occursin("class=\"dd-menu\"", member_project)
            @test occursin("#tag-add", member_project)
            @test !occursin("#tag-add", page(reader, "/project/$(project_id)"))

            experiment = page(editor, "/experiment/$(experiment_id)")
            @test occursin("#edit-name", experiment)
            @test occursin("action=\"/experiment/$(experiment_id)/edit\"", experiment)
            @test occursin("name=\"status\"", experiment)
            @test occursin("data-autosubmit", experiment)
            @test occursin("#tag-add", experiment)
            @test !occursin("/experiment/$(experiment_id)/delete", experiment)
            # v1 is registered from one of this experiment's iterations, so even the admin
            # sees the delete entry disabled with the reason.
            admin_experiment = page(admin, "/experiment/$(experiment_id)")
            @test occursin("class=\"dd-menu\"", admin_experiment)
            @test !occursin(
                "action=\"/experiment/$(experiment_id)/delete\"", admin_experiment
            )
            @test occursin("data-tip=\"Registered as v1 of forest.", admin_experiment)
            readonly = page(reader, "/experiment/$(experiment_id)")
            @test !occursin("#edit-name", readonly)
            @test !occursin("name=\"status\"", readonly)
            @test !occursin("class=\"dd-menu\"", readonly)

            running = page(editor, "/iteration/$(running_id)")
            @test occursin("#edit-notes", running)
            @test occursin("action=\"/iteration/$(running_id)/edit\"", running)
            @test occursin("#tag-add", running)
            @test occursin("action=\"/iteration/$(running_id)/kill\"", running)
            @test !occursin("Only running iterations", running)
            ended = page(admin, "/iteration/$(ended_id)")
            @test !occursin("#edit-notes", ended)
            @test !occursin("#tag-add", ended)
            @test occursin(">locked<", ended)
            @test occursin("Ended iterations are read-only", ended)
            # The kill entry stays visible but inert, with the reason one hover away.
            @test occursin("aria-disabled=\"true\"", ended)
            @test occursin("data-tip=\"Only running iterations can be killed.\"", ended)
            @test !occursin("action=\"/iteration/$(ended_id)/kill\"", ended)
            @test occursin(
                "data-tip=\"Registered as v1 of forest. Delete those versions first.\"",
                ended,
            )
            @test !occursin("action=\"/iteration/$(ended_id)/delete\"", ended)
            @test occursin(
                "action=\"/iteration/$(running_id)/delete\"",
                page(admin, "/iteration/$(running_id)"),
            )

            model = page(editor, "/model/$(model_id)")
            @test occursin("#edit-name", model)
            @test occursin("action=\"/model/$(model_id)/edit\"", model)
            @test occursin("name=\"stage\"", model)
            @test occursin("#version-$(version_id)", model)
            @test occursin("action=\"/modelversion/$(version_id)/edit\"", model)
            @test !occursin("/modelversion/$(version_id)/delete", model)
            @test !occursin("/model/$(model_id)/delete", model)
            admin_model = page(admin, "/model/$(model_id)")
            @test occursin("/modelversion/$(version_id)/delete", admin_model)
            @test occursin("/model/$(model_id)/delete", admin_model)
            @test !occursin("name=\"stage\"", page(reader, "/model/$(model_id)"))

            @test occursin(
                "Changes saved.",
                DearDiary.render_page(
                    "/project/$(project_id)",
                    DearDiary.PageContext(admin; path="/", query=Dict("ok" => "saved")),
                )[2],
            )
        end
    end

    @testset "edit, tag, kill, and delete posts" begin
        @with_deardiary_test_db begin
            admin = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(admin.id, "Editable")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Sweep"
            )
            running_id, _ = DearDiary.create_iteration(experiment_id)
            ended_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.update_iteration(ended_id, nothing, now(), DearDiary.SUCCEEDED)
            model_id, _ = DearDiary.create_model(project_id, "forest")
            v1, _ = DearDiary.create_modelversion(model_id, ended_id, nothing, "first")
            v2, _ = DearDiary.create_modelversion(model_id, running_id, nothing, "second")
            editor_id, _ = DearDiary.create_user("Edit", "Only", "editor", "pw")
            DearDiary.create_userpermission(editor_id, project_id, false, true, true, false)
            editor = DearDiary.get_user(editor_id)
            token = DearDiary._csrf_token(HTTP.Request("GET", "/"))
            post(viewer, path, fields; csrf=true) = DearDiary._handle_entity_post(
                DearDiary.PageContext(viewer; path=path, csrf=token),
                _ui_post(path, fields; csrf=csrf),
            )
            go(viewer, path, fields; csrf=true) =
                _ui_location(post(viewer, path, fields; csrf=csrf))

            @test go(
                admin, "/project/$(project_id)/edit", Dict("name" => "x"); csrf=false
            ) == "/project/$(project_id)?err=csrf"
            # Inline editors post one field at a time; the others stay as they are.
            @test go(admin, "/project/$(project_id)/edit", Dict("name" => "Renamed")) ==
                "/project/$(project_id)?ok=saved"
            @test go(
                admin, "/project/$(project_id)/edit", Dict("description" => "About it")
            ) == "/project/$(project_id)?ok=saved"
            @test DearDiary.get_project(project_id).name == "Renamed"
            @test DearDiary.get_project(project_id).description == "About it"
            @test go(admin, "/project/$(project_id)/edit", Dict("name" => "  ")) ==
                "/project/$(project_id)?err=name"
            @test go(editor, "/project/$(project_id)/edit", Dict("name" => "Nope")) ==
                "/project/$(project_id)?err=forbidden"
            @test go(admin, "/project/$(project_id)/tags", Dict("tag" => "tabular")) ==
                "/project/$(project_id)?ok=tag"
            @test go(admin, "/project/$(project_id)/tags", Dict("tag" => "tabular")) ==
                "/project/$(project_id)?err=tag_exists"
            @test go(admin, "/project/$(project_id)/tags", Dict("tag" => " ")) ==
                "/project/$(project_id)?err=tag_empty"
            @test [t.value for t in DearDiary.get_tags(DearDiary.Project, project_id)] == ["tabular"]

            exp_path = "/experiment/$(experiment_id)"
            @test go(editor, exp_path * "/edit", Dict("name" => "Sweep 2")) ==
                "$(exp_path)?ok=saved"
            @test go(
                editor,
                exp_path * "/edit",
                Dict("status" => string(Integer(DearDiary.FINISHED))),
            ) == "$(exp_path)?ok=saved"
            finished = DearDiary.get_experiment(experiment_id)
            @test finished.name == "Sweep 2"
            @test finished.status_id == Integer(DearDiary.FINISHED)
            @test !isnothing(finished.end_date)
            # A description edit after finishing must not disturb the status or end date.
            @test go(editor, exp_path * "/edit", Dict("description" => "d")) ==
                "$(exp_path)?ok=saved"
            @test DearDiary.get_experiment(experiment_id).status_id ==
                Integer(DearDiary.FINISHED)
            @test DearDiary.get_experiment(experiment_id).description == "d"
            @test go(
                editor,
                exp_path * "/edit",
                Dict("status" => string(Integer(DearDiary.IN_PROGRESS))),
            ) == "$(exp_path)?ok=saved"
            @test DearDiary.get_experiment(experiment_id).end_date === nothing
            @test go(editor, exp_path * "/edit", Dict("status" => "9")) ==
                "$(exp_path)?err=invalid"
            # The editor holds no create permission, so tags are refused; deletes too.
            @test go(editor, exp_path * "/tags", Dict("tag" => "hpo")) ==
                "$(exp_path)?err=forbidden"
            @test go(editor, exp_path * "/delete", Dict{String,String}()) ==
                "$(exp_path)?err=forbidden"
            @test go(admin, exp_path * "/tags", Dict("tag" => "hpo")) ==
                "$(exp_path)?ok=tag"

            run_path = "/iteration/$(running_id)"
            @test go(
                editor, run_path * "/edit", Dict("notes" => "typed in the dashboard")
            ) == "$(run_path)?ok=saved"
            @test DearDiary.get_iteration(running_id).notes == "typed in the dashboard"
            @test go(admin, run_path * "/tags", Dict("tag" => "wip")) ==
                "$(run_path)?ok=tag"
            ended_path = "/iteration/$(ended_id)"
            @test go(admin, ended_path * "/edit", Dict("notes" => "too late")) ==
                "$(ended_path)?err=locked"
            @test go(admin, ended_path * "/tags", Dict("tag" => "late")) ==
                "$(ended_path)?err=locked"
            @test go(admin, ended_path * "/kill", Dict{String,String}()) ==
                "$(ended_path)?err=locked"
            @test go(editor, run_path * "/kill", Dict{String,String}()) ==
                "$(run_path)?ok=killed"
            killed = DearDiary.get_iteration(running_id)
            @test killed.status_id == Integer(DearDiary.KILLED)
            @test !isnothing(killed.end_date)
            @test post(admin, exp_path * "/kill", Dict{String,String}()).status == 404

            model_path = "/model/$(model_id)"
            @test go(
                editor, model_path * "/edit", Dict("description" => "Production classifier")
            ) == "$(model_path)?ok=saved"
            @test DearDiary.get_model(model_id).description == "Production classifier"
            @test go(editor, model_path * "/edit", Dict("name" => "forest-2")) ==
                "$(model_path)?ok=saved"
            @test DearDiary.get_model(model_id).name == "forest-2"
            @test DearDiary.get_model(model_id).description == "Production classifier"
            # Deleting the ended iteration is blocked while v1 is registered from it.
            @test go(admin, ended_path * "/delete", Dict{String,String}()) ==
                "$(ended_path)?err=registered"
            blocked = DearDiary.render_page(
                ended_path, DearDiary.PageContext(admin; path=ended_path, csrf="tok")
            )[2]
            @test occursin("Registered as v1 of forest-2", blocked)
            @test occursin("aria-disabled=\"true\"", blocked)
            # Stage and description post separately from the versions table.
            @test go(
                editor,
                "/modelversion/$(v1)/edit",
                Dict("stage" => string(Integer(DearDiary.PRODUCTION))),
            ) == "$(model_path)?ok=saved"
            @test go(editor, "/modelversion/$(v2)/edit", Dict("description" => "newer")) ==
                "$(model_path)?ok=saved"
            @test DearDiary.get_modelversion(v1).stage_id == Integer(DearDiary.PRODUCTION)
            @test DearDiary.get_modelversion(v2).description == "newer"
            @test DearDiary.get_modelversion(v2).stage_id == Integer(DearDiary.NO_STAGE)
            @test go(
                editor,
                "/modelversion/$(v2)/edit",
                Dict("stage" => string(Integer(DearDiary.PRODUCTION))),
            ) == "$(model_path)?ok=saved"
            @test DearDiary.get_modelversion(v1).stage_id == Integer(DearDiary.ARCHIVED)
            @test go(editor, "/modelversion/$(v2)/edit", Dict("stage" => "7")) ==
                "$(model_path)?err=invalid"
            @test go(editor, "/modelversion/$(v1)/delete", Dict{String,String}()) ==
                "$(model_path)?err=forbidden"
            @test go(admin, "/modelversion/$(v1)/delete", Dict{String,String}()) ==
                "$(model_path)?ok=deleted"
            @test DearDiary.get_modelversion(v1) === nothing

            @test go(admin, ended_path * "/delete", Dict{String,String}()) ==
                "$(exp_path)?ok=deleted"
            @test DearDiary.get_iteration(ended_id) === nothing
            @test go(admin, model_path * "/delete", Dict{String,String}()) ==
                "/project/$(project_id)?ok=deleted"
            @test DearDiary.get_model(model_id) === nothing
            @test go(admin, exp_path * "/delete", Dict{String,String}()) ==
                "/project/$(project_id)?ok=deleted"
            @test DearDiary.get_experiment(experiment_id) === nothing
            @test go(admin, "/project/$(project_id)/delete", Dict{String,String}()) ==
                "/?ok=deleted"
            @test DearDiary.get_project(project_id) === nothing
            @test post(
                admin, "/project/$(project_id)/edit", Dict("name" => "gone")
            ).status == 404

            # Routed through the page handler like a browser post.
            other_id, _ = DearDiary.create_project(admin.id, "Other")
            routed = DearDiary._handle_page((
                request=_ui_post("/project/$(other_id)/edit", Dict("name" => "Other 2")),
            ))
            @test routed.status == 303
            @test _ui_location(routed) == "/project/$(other_id)?ok=saved"
        end
    end
end
