@testset verbose = true "ui/app helpers" begin
    @testset "_iteration_title" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "MyProject")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "IrisClassifier"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)

            @test DearDiary._iteration_title(nothing) == "DearDiary"
            # The title uses the per-experiment ordinal, not the opaque UUID; this is the
            # experiment's first (and only) iteration, so ordinal 1.
            @test DearDiary._iteration_title(iteration_id) ==
                "#1 · IrisClassifier · DearDiary"

            missing_id = "00000000-0000-0000-0000-000000000000"
            @test DearDiary._iteration_title(missing_id) ==
                "Iteration not found · DearDiary"
        end
    end

    @testset "_serve_favicon_ico" begin
        response = DearDiary._serve_favicon_ico(nothing)
        @test response.status == 200
        @test HTTP.header(response, "Content-Type") == "image/svg+xml"
        @test HTTP.header(response, "Cache-Control") == "public, max-age=86400"

        logo_path = joinpath(pkgdir(DearDiary), "assets", "logo.svg")
        @test response.body == read(logo_path)
    end

    @testset "_LOGO_PATH resolves to assets/logo.svg on disk" begin
        @test isfile(DearDiary._LOGO_PATH)
        @test basename(DearDiary._LOGO_PATH) == "logo.svg"
    end

    @testset "_build_metrics_figure renders inline SVG without external JS" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "ChartProject")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Experiment"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            for step in 1:5
                DearDiary.create_metric(iteration_id, "loss", 1.0 / step; step=step)
                DearDiary.create_metric(
                    iteration_id, "accuracy", 0.5 + 0.1 * step; step=step
                )
            end

            metrics = DearDiary.get_metrics(iteration_id)
            svg = DearDiary._build_metrics_figure(metrics)
            html = sprint(show, MIME("text/html"), svg)

            @test occursin("<svg", html)
            @test occursin("viewBox=\"0 0 800 380\"", html)

            # No Plotly: no third-party bundle, no JSON trace blocks, no <script> tags.
            @test !occursin("plotly", lowercase(html))
            @test !occursin("application/json", lowercase(html))
            @test !occursin("<script", lowercase(html))

            # One polyline per series.
            @test length(collect(eachmatch(r"<polyline", html))) == 2

            # 5 points per series × 2 series = 10 data circles, plus 2 legend dots.
            @test length(collect(eachmatch(r"<circle", html))) == 12

            # Tooltips encode the metric name, step, and value.
            @test occursin("loss: step 1, value 1", html)
            @test occursin("accuracy: step 5, value 1", html)

            # Axis labels render.
            @test occursin(">step<", html)
            @test occursin(">value<", html)
        end
    end

    @testset "_build_metrics_figure handles a single-point series without div-by-zero" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "P")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "E"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.create_metric(iteration_id, "loss", 0.5; step=1)

            metrics = DearDiary.get_metrics(iteration_id)
            svg = DearDiary._build_metrics_figure(metrics)
            html = sprint(show, MIME("text/html"), svg)

            @test occursin("<svg", html)
            @test length(collect(eachmatch(r"<polyline", html))) == 1
            # One data circle + one legend dot.
            @test length(collect(eachmatch(r"<circle", html))) == 2
        end
    end

    @testset "_format_tick / _chart_color helpers" begin
        @test DearDiary._format_tick(1.0) == "1"
        @test DearDiary._format_tick(0.5) == "0.5"
        @test DearDiary._format_tick(2 / 3) == "0.6667"
        @test DearDiary._format_tick(0) == "0"

        @test DearDiary._chart_color(1) == "#4e79a7"
        @test DearDiary._chart_color(10) == "#bab0ab"
        # Wraps around after exhausting the 10-color palette.
        @test DearDiary._chart_color(11) == "#4e79a7"
        @test DearDiary._chart_color(20) == "#bab0ab"
    end

    @testset "_tick_values_y / _tick_values_x" begin
        @test DearDiary._tick_values_y(0.0, 1.0, 5) == [0.0, 0.25, 0.5, 0.75, 1.0]
        @test DearDiary._tick_values_y(5.0, 5.0, 5) == [5.0]

        @test DearDiary._tick_values_x(1, 5) == [1, 2, 3, 4, 5]
        @test DearDiary._tick_values_x(0, 100, 5) == [0, 25, 50, 75, 100]
        @test DearDiary._tick_values_x(7, 7) == [7]
    end

    @testset "_status_glyph maps every status to a distinct character" begin
        @test DearDiary._status_glyph(Integer(DearDiary.SUCCEEDED)) == "✓"
        @test DearDiary._status_glyph(Integer(DearDiary.FAILED)) == "✗"
        @test DearDiary._status_glyph(Integer(DearDiary.RUNNING)) == "▶"
        @test DearDiary._status_glyph(Integer(DearDiary.KILLED)) == "⊘"
        @test DearDiary._status_glyph(999) == "?"
    end

    @testset "_relative_time formats deltas across the unit ladder" begin
        ref = DateTime(2026, 6, 5, 12, 0, 0)
        @test DearDiary._relative_time(ref - Dates.Second(30), ref) == "just now"
        @test DearDiary._relative_time(ref - Dates.Minute(5), ref) == "5m ago"
        @test DearDiary._relative_time(ref - Dates.Minute(59), ref) == "59m ago"
        @test DearDiary._relative_time(ref - Dates.Hour(2), ref) == "2h ago"
        @test DearDiary._relative_time(ref - Dates.Hour(23), ref) == "23h ago"
        @test DearDiary._relative_time(ref - Dates.Day(3), ref) == "3d ago"
        @test DearDiary._relative_time(ref - Dates.Day(6), ref) == "6d ago"
        # Same-year fallback drops the year.
        @test DearDiary._relative_time(DateTime(2026, 3, 5, 9, 0, 0), ref) == "Mar 5"
        # Different-year entries include the year.
        @test DearDiary._relative_time(DateTime(2025, 11, 1, 9, 0, 0), ref) == "Nov 1, 2025"
        # Clock-skew safety: future timestamps collapse to "just now".
        @test DearDiary._relative_time(ref + Dates.Hour(1), ref) == "just now"
    end

    @testset "sidebar labels iterations as 'Iteration N · time' with glyph" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Project")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "Experiment"
            )
            DearDiary.create_iteration(experiment_id)
            DearDiary.create_iteration(experiment_id)
            DearDiary.create_iteration(experiment_id)

            selected = DearDiary.Observables.Observable{DearDiary.Optional{String}}(nothing)
            sidebar = DearDiary._render_sidebar(user, selected)
            html = sprint(show, MIME("text/html"), sidebar)

            # Per-experiment ordinals, not database ids.
            @test occursin("Iteration 1", html)
            @test occursin("Iteration 2", html)
            @test occursin("Iteration 3", html)
            # The previous `#N` style label is gone.
            @test !occursin(">#1<", html)
            # Running status glyph appears for freshly-created iterations.
            @test occursin("▶", html)
            # Relative-time suffix renders.
            @test occursin("just now", html) || occursin("ago", html)
        end
    end

    @testset "sidebar rows wire the click-driven selection highlight" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "HlProject")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "HlExp"
            )
            DearDiary.create_iteration(experiment_id)

            selected = DearDiary.Observables.Observable{DearDiary.Optional{String}}(nothing)
            html = sprint(
                show, MIME("text/html"), DearDiary._render_sidebar(user, selected)
            )

            # The click handler toggles the active class on the client.
            @test occursin("dd-iter-active", html)
            @test occursin("classList", html)
            # The highlight style is defined.
            @test occursin("dd-iter-active", DearDiary._UI_STYLES)
        end
    end

    @testset "_format_duration formats across the unit ladder" begin
        @test DearDiary._format_duration(DearDiary.Dates.Millisecond(500)) == "500 ms"
        @test DearDiary._format_duration(DearDiary.Dates.Millisecond(1060)) == "1.06s"
        @test DearDiary._format_duration(DearDiary.Dates.Millisecond(90000)) == "1m 30s"
        @test DearDiary._format_duration(DearDiary.Dates.Millisecond(3_660_000)) == "1h 1m"
    end

    @testset "iteration header surfaces duration, notes, and tags" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "HdrProject")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "HdrExp"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.add_tag(DearDiary.Iteration, iteration_id, "baseline")
            DearDiary.update_iteration(
                iteration_id, "first run", now(), DearDiary.SUCCEEDED
            )
            iteration = DearDiary.get_iteration(iteration_id)

            html = sprint(
                show, MIME("text/html"), DearDiary._render_iteration_header(iteration)
            )
            @test occursin("Duration:", html)
            @test occursin("Notes:", html)
            @test occursin("first run", html)
            @test occursin("Tags:", html)
            @test occursin("baseline", html)
            @test occursin("dd-tag", html)
        end
    end

    @testset "environment card surfaces the captured snapshot" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "EnvProject")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "EnvExp"
            )

            # No snapshot captured yet → explicit empty state.
            bare_id, _ = DearDiary.create_iteration(experiment_id)
            bare = DearDiary.get_iteration(bare_id)
            bare_html = sprint(
                show, MIME("text/html"), DearDiary._render_environment_card(bare)
            )
            @test occursin("Environment", bare_html)
            @test occursin("No environment captured.", bare_html)

            # With a captured (here, hand-set) snapshot → fields render, dirty flag shows.
            snap_id, _ = DearDiary.create_iteration(experiment_id)
            DearDiary.update(
                DearDiary.Iteration,
                snap_id;
                julia_version="1.11.0",
                git_sha="abc1234",
                git_dirty=1,
                entrypoint="train.jl",
            )
            snap = DearDiary.get_iteration(snap_id)
            snap_html = sprint(
                show, MIME("text/html"), DearDiary._render_environment_card(snap)
            )
            @test occursin("1.11.0", snap_html)
            @test occursin("abc1234", snap_html)
            @test occursin("dirty", snap_html)
            @test occursin("train.jl", snap_html)
        end
    end
end
