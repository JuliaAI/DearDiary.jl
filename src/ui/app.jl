"""
    build_ui_app()::Bonito.App

Build the [`Bonito.App`](https://simondanisch.github.io/Bonito.jl/) that backs the embedded
DearDiary dashboard. The app is single-page and reactive: a sidebar lists every project,
experiment, and iteration the seeded default user can read, and the main pane renders the
detail view for whichever iteration the user clicked last.

The dashboard calls DearDiary's service-layer functions in-process. The HTTP REST API runs
unchanged on the sibling port.
"""
# Register the package logo as the browser favicon once at module-load time so Bonito
# serves it as a cached static asset rather than re-encoding the SVG bytes on each render.
const _LOGO_PATH = joinpath(@__DIR__, "..", "..", "assets", "logo.svg")
const _FAVICON_ASSET = Bonito.Asset(_LOGO_PATH)

"""
    _serve_favicon_ico(context)::HTTP.Response

Browsers auto-request `/favicon.ico` before they finish parsing the document `<head>`.
Without a handler that path 404s and pollutes the developer console. The handler below
reads the same SVG that backs the explicit `<link rel="icon">` and serves it with the
right MIME type so the auto-request resolves even when the page has not finished rendering.
"""
function _serve_favicon_ico(_context)::HTTP.Response
    return HTTP.Response(
        200,
        ["Content-Type" => "image/svg+xml", "Cache-Control" => "public, max-age=86400"];
        body=read(_LOGO_PATH),
    )
end

function build_ui_app()::Bonito.App
    return Bonito.App(; title="DearDiary") do session::Bonito.Session
        user = get_user_by_username("default")
        selected = Observables.Observable{Optional{String}}(nothing)

        sidebar = _render_sidebar(user, selected)
        main_content = Observables.map(_render_iteration_detail, selected)

        # Update the browser tab title client-side whenever `selected` changes. The static
        # `<title>DearDiary</title>` below covers the landing page; subsequent selections
        # push a new title through the WebSocket without a re-render.
        title_text = Observables.map(_iteration_title, selected)
        Bonito.onjs(session, title_text, js"t => document.title = t")

        # Return explicit `<html>`/`<head>`/`<body>` so Bonito's `find_head_body` walker
        # locates the head and threads session styles into it. Without an explicit head,
        # Bonito auto-generates one and the favicon `<link>` ends up inside `<body>`,
        # where Firefox ignores it.
        return Bonito.DOM.html(
            Bonito.DOM.head(
                Bonito.DOM.meta(; charset="UTF-8"),
                Bonito.DOM.meta(;
                    name="viewport", content="width=device-width, initial-scale=1.0"
                ),
                Bonito.DOM.title("DearDiary"),
                Bonito.DOM.link(; rel="icon", type="image/svg+xml", href=_FAVICON_ASSET),
                Bonito.DOM.style(_UI_STYLES),
            ),
            Bonito.DOM.body(
                Bonito.DOM.div(
                    sidebar,
                    Bonito.DOM.main(main_content; class="dd-main"),
                    ;
                    class="dd-layout",
                ),
            ),
        )
    end
end

const _UI_STYLES = """
    * { box-sizing: border-box; }
    body { margin: 0; font-family: system-ui, -apple-system, "Segoe UI", sans-serif; color: #1f2933; background: #f5f7fa; }
    .dd-layout { display: grid; grid-template-columns: 320px 1fr; min-height: 100vh; }
    .dd-sidebar { background: #1f2933; color: #e4e7eb; padding: 1.25rem 1rem; overflow-y: auto; display: flex; flex-direction: column; }
    .dd-sidebar-footer { margin-top: auto; padding-top: 1rem; border-top: 1px solid #323f4b; }
    .dd-docs-link { color: #9aa5b1; text-decoration: none; font-size: 0.85rem; display: inline-flex; align-items: center; gap: 0.25rem; }
    .dd-docs-link:hover { color: #f5f7fa; }
    .dd-brand { display: flex; align-items: center; gap: 0.5rem; margin: 0 0 1.25rem 0; }
    .dd-brand-logo { width: 28px; height: 28px; flex-shrink: 0; }
    .dd-brand-text { font-size: 1.05rem; font-weight: 600; color: #f5f7fa; letter-spacing: 0.01em; }
    .dd-sidebar ul { list-style: none; padding-left: 0.75rem; margin: 0.25rem 0; }
    .dd-project { font-weight: 600; margin-top: 0.75rem; color: #f5f7fa; }
    .dd-experiment { font-weight: 500; margin-top: 0.5rem; color: #cbd2d9; }
    .dd-iter-link { display: block; padding: 0.2rem 0.4rem; color: #9aa5b1; text-decoration: none; border-radius: 0.25rem; font-size: 0.85rem; }
    .dd-iter-link:hover { background: #323f4b; color: #e4e7eb; }
    .dd-iter-active { background: #323f4b; box-shadow: inset 3px 0 0 #4e79a7; }
    .dd-iter-running { color: #ffd479; }
    .dd-iter-failed { color: #ff9b9b; }
    .dd-iter-killed { color: #c8a2c8; }
    .dd-main { padding: 2rem 2.5rem; overflow-y: auto; }
    .dd-empty { color: #7b8794; font-style: italic; }
    .dd-card { background: white; border: 1px solid #e4e7eb; border-radius: 0.5rem; padding: 1.25rem 1.5rem; margin-bottom: 1.5rem; box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04); }
    .dd-card h3 { margin-top: 0; font-size: 1rem; text-transform: uppercase; letter-spacing: 0.05em; color: #52606d; }
    .dd-card table { width: 100%; border-collapse: collapse; }
    .dd-card th, .dd-card td { padding: 0.5rem 0.75rem; text-align: left; border-bottom: 1px solid #f0f4f8; font-size: 0.9rem; }
    .dd-card th { color: #7b8794; font-weight: 500; font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.04em; }
    .dd-badge { display: inline-block; padding: 0.15rem 0.6rem; border-radius: 9999px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.05em; }
    .dd-badge-running { background: #fff3cd; color: #856404; }
    .dd-badge-succeeded { background: #d1fae5; color: #065f46; }
    .dd-badge-failed { background: #fee2e2; color: #991b1b; }
    .dd-badge-killed { background: #ede9fe; color: #5b21b6; }
    .dd-meta { color: #52606d; font-size: 0.9rem; margin: 0.25rem 0; }
    .dd-meta b { color: #1f2933; font-weight: 600; }
    .dd-meta-id { color: #7b8794; font-size: 0.82rem; font-family: ui-monospace, monospace; word-break: break-all; }
    .dd-mono { font-family: ui-monospace, monospace; font-size: 0.85rem; word-break: break-all; }
    .dd-tag { display: inline-block; background: #e4e7eb; color: #3e4c59; border-radius: 9999px; padding: 0.1rem 0.55rem; font-size: 0.75rem; font-weight: 600; margin-right: 0.35rem; }
    .dd-error { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; padding: 0.75rem 1rem; border-radius: 0.375rem; font-family: ui-monospace, monospace; font-size: 0.85rem; white-space: pre-wrap; }
"""

function _render_sidebar(user, selected::Observables.Observable)
    project_blocks = Vector{Any}()
    for project in get_projects(user)
        push!(project_blocks, _render_project_block(project, selected))
    end
    brand = Bonito.DOM.div(
        Bonito.DOM.img(; src=_FAVICON_ASSET, alt="", class="dd-brand-logo"),
        Bonito.DOM.span("DearDiary"; class="dd-brand-text"),
        ;
        class="dd-brand",
    )
    footer = Bonito.DOM.div(
        Bonito.DOM.a(
            "Docs ↗";
            href="https://juliaai.github.io/DearDiary.jl/dev/",
            target="_blank",
            rel="noopener noreferrer",
            class="dd-docs-link",
        ),
        ;
        class="dd-sidebar-footer",
    )
    return Bonito.DOM.aside(
        brand,
        if (isempty(project_blocks))
            Bonito.DOM.p("No projects yet."; class="dd-empty")
        else
            Bonito.DOM.div(project_blocks...)
        end,
        footer,
        ;
        class="dd-sidebar",
    )
end

function _render_project_block(project, selected::Observables.Observable)
    experiment_blocks = [
        _render_experiment_block(experiment, selected) for
        experiment in get_experiments(project.id)
    ]
    return Bonito.DOM.div(
        Bonito.DOM.div(project.name; class="dd-project"),
        Bonito.DOM.ul(experiment_blocks...),
    )
end

function _render_experiment_block(experiment, selected::Observables.Observable)
    iterations = get_iterations(experiment.id)
    # Sort by creation date and assign per-experiment ordinals. The sidebar labels
    # iterations as "Iteration 1, 2, 3..." within each experiment rather than exposing the
    # canonical id. The canonical id stays visible in the detail pane header. (UUID ids are
    # not chronologically ordered, so creation order comes from `created_date`.)
    sorted_iters = sort(iterations; by=it -> it.created_date)
    ordinals = Dict{String,Int}(it.id => i for (i, it) in enumerate(sorted_iters))

    # Group children by parent so the tree renderer can recurse one level at a time.
    # Top-level iterations (no `parent_iteration_id`) become the roots of the tree.
    children_by_parent = Dict{String,Vector{Iteration}}()
    top_level = Iteration[]
    for iteration in sorted_iters
        if isnothing(iteration.parent_iteration_id)
            push!(top_level, iteration)
        else
            push!(
                get!(children_by_parent, iteration.parent_iteration_id, Iteration[]),
                iteration,
            )
        end
    end

    iteration_items = [
        _render_iteration_node(iteration, children_by_parent, ordinals, selected) for
        iteration in top_level
    ]
    return Bonito.DOM.li(
        Bonito.DOM.div(experiment.name; class="dd-experiment"),
        Bonito.DOM.ul(iteration_items...),
    )
end

function _render_iteration_node(
    iteration::Iteration,
    children_by_parent::Dict{String,Vector{Iteration}},
    ordinals::Dict{String,Int},
    selected::Observables.Observable,
)
    children = get(children_by_parent, iteration.id, Iteration[])
    node_children = Any[_render_iteration_anchor(iteration, ordinals, selected)]
    if !(isempty(children))
        child_nodes = [
            _render_iteration_node(child, children_by_parent, ordinals, selected) for
            child in children
        ]
        push!(node_children, Bonito.DOM.ul(child_nodes...))
    end
    return Bonito.DOM.li(node_children...)
end

function _render_iteration_anchor(
    iteration::Iteration, ordinals::Dict{String,Int}, selected::Observables.Observable
)
    status = iteration.status_id
    class = "dd-iter-link"
    if status == (Integer(RUNNING))
        class *= " dd-iter-running"
    elseif status == (Integer(FAILED))
        class *= " dd-iter-failed"
    elseif status == (Integer(KILLED))
        class *= " dd-iter-killed"
    end
    ordinal = get(ordinals, iteration.id, 0)
    label = "$(_status_glyph(status)) Iteration $(ordinal) · $(_relative_time(iteration.created_date))"
    # Selection is click-driven, so the persistent highlight is moved on the client: clear the
    # active class from every row, set it on the clicked one, then notify the `selected`
    # observable that drives the detail pane. Doing it in the click handler avoids rebuilding
    # the sidebar (which would lose scroll position) on every selection.
    return Bonito.DOM.a(
        label;
        href="#",
        class=class,
        onclick=Bonito.js"""event => {
            event.preventDefault();
            document.querySelectorAll('.dd-iter-link').forEach(el => el.classList.remove('dd-iter-active'));
            event.currentTarget.classList.add('dd-iter-active');
            $(selected).notify($(iteration.id));
        }"""
    )
end

# Iterations are surfaced to the user by their per-experiment ordinal ("Iteration 1, 2, ...")
# rather than their opaque UUID. `get_iterations` returns the experiment's iterations ordered by
# `created_date`, so the 1-based position in that list is the same ordinal the sidebar assigns.
function _iteration_ordinal(iteration)::Int
    siblings = get_iterations(iteration.experiment_id)
    idx = findfirst(sibling -> sibling.id == iteration.id, siblings)
    return isnothing(idx) ? 0 : idx
end

function _iteration_title(iteration_id::Optional{<:AbstractString})::String
    if isnothing(iteration_id)
        return "DearDiary"
    end
    iteration = get_iteration(iteration_id)
    if isnothing(iteration)
        return "Iteration not found · DearDiary"
    end
    experiment = get_experiment(iteration.experiment_id)
    experiment_name = (isnothing(experiment)) ? "?" : experiment.name
    return "#$(_iteration_ordinal(iteration)) · $(experiment_name) · DearDiary"
end

function _render_iteration_detail(iteration_id::Optional{<:AbstractString})
    if isnothing(iteration_id)
        return Bonito.DOM.div(
            Bonito.DOM.p(
                "Pick an iteration from the sidebar to see its parameters, metrics, " *
                "and reproducibility metadata.";
                class="dd-empty",
            ),
        )
    end

    iteration = get_iteration(iteration_id)
    if isnothing(iteration)
        return Bonito.DOM.div(Bonito.DOM.p("Iteration $(iteration_id) not found."))
    end

    return Bonito.DOM.div(
        _render_iteration_header(iteration),
        _render_parameters_card(iteration),
        _render_metrics_card(iteration),
        _render_environment_card(iteration),
    )
end

function _render_iteration_header(iteration)
    badge_class, badge_text = _status_chrome(iteration.status_id)
    experiment = get_experiment(iteration.experiment_id)
    experiment_name = (isnothing(experiment)) ? "?" : experiment.name

    rows = Any[
        Bonito.DOM.h2("Iteration $(_iteration_ordinal(iteration))"),
        Bonito.DOM.span(badge_text; class="dd-badge $badge_class"),
        Bonito.DOM.p(Bonito.DOM.b("Experiment: "), experiment_name; class="dd-meta"),
        Bonito.DOM.p(Bonito.DOM.b("ID: "), iteration.id; class="dd-meta dd-meta-id"),
        Bonito.DOM.p(
            Bonito.DOM.b("Created: "), string(iteration.created_date); class="dd-meta"
        ),
    ]
    if !(isnothing(iteration.end_date))
        push!(
            rows,
            Bonito.DOM.p(
                Bonito.DOM.b("Ended: "), string(iteration.end_date); class="dd-meta"
            ),
        )
        push!(
            rows,
            Bonito.DOM.p(
                Bonito.DOM.b("Duration: "),
                _format_duration(iteration.end_date - iteration.created_date);
                class="dd-meta",
            ),
        )
    end
    if !(isnothing(iteration.parent_iteration_id))
        parent = get_iteration(iteration.parent_iteration_id)
        parent_ordinal = (isnothing(parent)) ? "?" : string(_iteration_ordinal(parent))
        push!(
            rows,
            Bonito.DOM.p(
                Bonito.DOM.b("Parent iteration: "), "#$(parent_ordinal)"; class="dd-meta"
            ),
        )
    end
    if !(isempty(iteration.notes))
        push!(rows, Bonito.DOM.p(Bonito.DOM.b("Notes: "), iteration.notes; class="dd-meta"))
    end
    tags = get_tags(Iteration, iteration.id)
    if !(isempty(tags))
        chips = [Bonito.DOM.span(tag.value; class="dd-tag") for tag in tags]
        push!(rows, Bonito.DOM.p(Bonito.DOM.b("Tags: "), chips...; class="dd-meta"))
    end
    if !(isempty(iteration.error_message))
        push!(rows, Bonito.DOM.div(iteration.error_message; class="dd-error"))
    end
    return Bonito.DOM.section(rows...; class="dd-card")
end

# Render a coarse human-readable duration. Sub-second runs show milliseconds; otherwise the
# largest one or two units (s, m, h) so a quick scan reads "1.06s" / "2m 3s" / "1h 12m".
function _format_duration(d::Millisecond)::String
    ms = d.value
    ms < 0 && return "—"
    ms < 1000 && return "$(ms) ms"
    s = ms / 1000
    s < 60 && return "$(round(s; digits=2))s"
    if s < 3600
        m, rem = divrem(round(Int, s), 60)
        return "$(m)m $(rem)s"
    end
    h, rem = divrem(round(Int, s), 3600)
    return "$(h)h $(rem ÷ 60)m"
end

function _render_environment_card(iteration)
    has_env =
        !(isempty(iteration.julia_version)) ||
        !(isempty(iteration.git_sha)) ||
        !(isempty(iteration.entrypoint))
    body = if !has_env
        Bonito.DOM.p("No environment captured."; class="dd-empty")
    else
        git = if (isempty(iteration.git_sha))
            "—"
        elseif iteration.git_dirty
            "$(iteration.git_sha) (dirty)"
        else
            iteration.git_sha
        end
        Bonito.DOM.table(
            Bonito.DOM.tbody(
                Bonito.DOM.tr(
                    Bonito.DOM.td(Bonito.DOM.b("Julia version")),
                    Bonito.DOM.td(
                        if (isempty(iteration.julia_version))
                            "—"
                        else
                            iteration.julia_version
                        end,
                    ),
                ),
                Bonito.DOM.tr(
                    Bonito.DOM.td(Bonito.DOM.b("Git commit")),
                    Bonito.DOM.td(Bonito.DOM.span(git; class="dd-mono")),
                ),
                Bonito.DOM.tr(
                    Bonito.DOM.td(Bonito.DOM.b("Entrypoint")),
                    Bonito.DOM.td(
                        Bonito.DOM.span(
                            if (isempty(iteration.entrypoint))
                                "—"
                            else
                                iteration.entrypoint
                            end;
                            class="dd-mono",
                        ),
                    ),
                ),
            ),
        )
    end
    return Bonito.DOM.section(Bonito.DOM.h3("Environment"), body; class="dd-card")
end

function _status_chrome(status_id::Integer)::Tuple{String,String}
    if status_id == (Integer(RUNNING))
        return ("dd-badge-running", "running")
    elseif status_id == (Integer(SUCCEEDED))
        return ("dd-badge-succeeded", "succeeded")
    elseif status_id == (Integer(FAILED))
        return ("dd-badge-failed", "failed")
    elseif status_id == (Integer(KILLED))
        return ("dd-badge-killed", "killed")
    end
    return ("dd-badge-running", "unknown")
end

function _status_glyph(status_id::Integer)::String
    status_id == (Integer(RUNNING)) && return "▶"
    status_id == (Integer(SUCCEEDED)) && return "✓"
    status_id == (Integer(FAILED)) && return "✗"
    status_id == (Integer(KILLED)) && return "⊘"
    return "?"
end

function _relative_time(dt::DateTime, ref::DateTime=now())::String
    delta_s = max(0, (ref - dt).value / 1000)
    delta_s < 60 && return "just now"
    delta_s < 3600 && return "$(round(Int, delta_s / 60))m ago"
    delta_s < 86400 && return "$(round(Int, delta_s / 3600))h ago"
    delta_s < 7 * 86400 && return "$(round(Int, delta_s / 86400))d ago"
    Dates.year(dt) == Dates.year(ref) && return Dates.format(dt, "u d")
    return Dates.format(dt, "u d, yyyy")
end

function _render_parameters_card(iteration)
    params = get_parameters(iteration.id)
    body = if (isempty(params))
        Bonito.DOM.p("No parameters recorded."; class="dd-empty")
    else
        Bonito.DOM.table(
            Bonito.DOM.thead(Bonito.DOM.tr(Bonito.DOM.th("Key"), Bonito.DOM.th("Value"))),
            Bonito.DOM.tbody(
                [
                    Bonito.DOM.tr(Bonito.DOM.td(p.key), Bonito.DOM.td(p.value)) for
                    p in params
                ]...,
            ),
        )
    end
    return Bonito.DOM.section(Bonito.DOM.h3("Parameters"), body; class="dd-card")
end

function _render_metrics_card(iteration)
    metrics = get_metrics(iteration.id)
    if isempty(metrics)
        return Bonito.DOM.section(
            Bonito.DOM.h3("Metrics"),
            Bonito.DOM.p("No metrics recorded."; class="dd-empty"),
            ;
            class="dd-card",
        )
    end
    return Bonito.DOM.section(
        Bonito.DOM.h3("Metrics"), _build_metrics_figure(metrics), ; class="dd-card"
    )
end

const _CHART_W = 800
const _CHART_H = 380
const _MARGIN_L = 60
const _MARGIN_R = 20
const _MARGIN_T = 30
const _MARGIN_B = 50

# Tableau 10 ordered for readability against the off-white card background. Series
# beyond the tenth wrap around the palette.
const _CHART_COLORS = [
    "#4e79a7",
    "#f28e2c",
    "#e15759",
    "#76b7b2",
    "#59a14f",
    "#edc949",
    "#af7aa1",
    "#ff9da7",
    "#9c755f",
    "#bab0ab",
]

_chart_color(idx::Integer) = _CHART_COLORS[((idx - 1) % length(_CHART_COLORS)) + 1]

function _scale_x(x::Real, x_min::Real, x_max::Real, plot_w::Real)
    x_max == x_min ? plot_w / 2 : (x - x_min) / (x_max - x_min) * plot_w
end

function _scale_y(y::Real, y_min::Real, y_max::Real, plot_h::Real)
    y_max == y_min ? plot_h / 2 : plot_h - (y - y_min) / (y_max - y_min) * plot_h
end

function _format_tick(v::Real)
    v == round(v) && return string(Int(round(v)))
    return string(round(v; sigdigits=4))
end

function _tick_values_y(y_min::Real, y_max::Real, n::Integer=5)
    y_max == y_min && return Float64[float(y_min)]
    step = (y_max - y_min) / (n - 1)
    return Float64[y_min + i * step for i in 0:(n - 1)]
end

function _tick_values_x(x_min::Integer, x_max::Integer, n::Integer=5)
    x_max == x_min && return Int64[x_min]
    span = x_max - x_min
    span <= n && return Int64[x for x in x_min:x_max]
    step = span / (n - 1)
    return unique(Int64[round(Int64, x_min + i * step) for i in 0:(n - 1)])
end

function _build_metrics_figure(metrics)
    # Render the chart as inline SVG with no external JS bundle. The response bytes are
    # ready to paint as soon as they reach the browser. Hover tooltips live in each
    # `<circle>`'s `<title>` child, which browsers surface as a native tooltip.
    grouped = Dict{String,Vector{Tuple{Int64,Float64}}}()
    for m in metrics
        push!(get!(grouped, m.key, Tuple{Int64,Float64}[]), (m.step, m.value))
    end
    for (_, points) in grouped
        sort!(points; by=p -> p[1])
    end

    plot_w = _CHART_W - _MARGIN_L - _MARGIN_R
    plot_h = _CHART_H - _MARGIN_T - _MARGIN_B

    all_xs = Int64[]
    all_ys = Float64[]
    for (_, points) in grouped
        for (x, y) in points
            push!(all_xs, x)
            push!(all_ys, y)
        end
    end
    x_min, x_max = extrema(all_xs)
    y_min, y_max = extrema(all_ys)

    axis_elements = Any[]
    for y in _tick_values_y(y_min, y_max)
        py = _scale_y(y, y_min, y_max, plot_h)
        push!(
            axis_elements,
            Bonito.SVG.line(;
                x1=0, x2=plot_w, y1=py, y2=py, stroke="#e4e7eb", strokeWidth=1
            ),
        )
        push!(
            axis_elements,
            Bonito.SVG.text(
                _format_tick(y);
                x=-8,
                y=py + 4,
                fill="#52606d",
                fontSize=11,
                textAnchor="end",
            ),
        )
    end
    for x in _tick_values_x(x_min, x_max)
        px = _scale_x(x, x_min, x_max, plot_w)
        push!(
            axis_elements,
            Bonito.SVG.text(
                string(x);
                x=px,
                y=plot_h + 18,
                fill="#52606d",
                fontSize=11,
                textAnchor="middle",
            ),
        )
    end
    push!(
        axis_elements,
        Bonito.SVG.line(;
            x1=0, x2=plot_w, y1=plot_h, y2=plot_h, stroke="#cbd2d9", strokeWidth=1
        ),
    )
    push!(
        axis_elements,
        Bonito.SVG.line(; x1=0, x2=0, y1=0, y2=plot_h, stroke="#cbd2d9", strokeWidth=1),
    )
    push!(
        axis_elements,
        Bonito.SVG.text(
            "step";
            x=plot_w / 2,
            y=plot_h + 38,
            fill="#52606d",
            fontSize=12,
            textAnchor="middle",
        ),
    )
    push!(
        axis_elements,
        Bonito.SVG.text(
            "value";
            x=-44,
            y=plot_h / 2,
            fill="#52606d",
            fontSize=12,
            textAnchor="middle",
            transform="rotate(-90 -44 $(plot_h / 2))",
        ),
    )

    series_keys = sort(collect(keys(grouped)))
    series_elements = Any[]
    for (i, key) in enumerate(series_keys)
        color = _chart_color(i)
        points = grouped[key]
        points_str = join(
            (
                "$(_scale_x(x, x_min, x_max, plot_w)),$(_scale_y(y, y_min, y_max, plot_h))"
                for (x, y) in points
            ),
            " ",
        )
        push!(
            series_elements,
            Bonito.SVG.polyline(;
                points=points_str, stroke=color, fill="none", strokeWidth=2
            ),
        )
        # Hyperscript treats `<circle>` as void, so the tooltip lives in a sibling
        # `<title>` inside a per-point `<g>`. Browsers show the group title on hover.
        point_groups = Any[
            Bonito.SVG.g(
                Bonito.SVG.title("$(key): step $(x), value $(_format_tick(y))"),
                Bonito.SVG.circle(;
                    cx=_scale_x(x, x_min, x_max, plot_w),
                    cy=_scale_y(y, y_min, y_max, plot_h),
                    r=3,
                    fill=color,
                ),
            ) for (x, y) in points
        ]
        push!(series_elements, Bonito.SVG.g(point_groups...))
    end

    legend_elements = Any[]
    legend_x = 0.0
    for (i, key) in enumerate(series_keys)
        color = _chart_color(i)
        push!(
            legend_elements, Bonito.SVG.circle(; cx=legend_x + 6, cy=-14, r=4, fill=color)
        )
        push!(
            legend_elements,
            Bonito.SVG.text(key; x=legend_x + 16, y=-10, fill="#1f2933", fontSize=11),
        )
        legend_x += 22 + length(key) * 7
    end

    return Bonito.SVG.svg(
        Bonito.SVG.g(
            axis_elements...,
            series_elements...,
            legend_elements...;
            transform="translate($(_MARGIN_L),$(_MARGIN_T))",
        );
        viewBox="0 0 $(_CHART_W) $(_CHART_H)",
        xmlns="http://www.w3.org/2000/svg",
        style="width:100%;height:380px;display:block;",
    )
end
