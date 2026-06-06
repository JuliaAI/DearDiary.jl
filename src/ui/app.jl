"""
    build_ui_app()::Bonito.App

Build the [`Bonito.App`](https://simondanisch.github.io/Bonito.jl/) that backs the embedded
DearDiary dashboard. The app is single-page and reactive: a sidebar lists every project,
experiment, and iteration the seeded default user can read, and the main pane renders the
detail view for whichever iteration the user clicked last.

The dashboard calls DearDiary's service-layer functions in-process. The HTTP REST API runs
unchanged on the sibling port.
"""
# The package logo doubles as the browser favicon. Registering it once at module-load time
# means Bonito serves it as a cached static asset rather than re-encoding the SVG bytes on
# every page render.
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
        user = "default" |> get_user
        selected = Observables.Observable{Optional{Int64}}(nothing)

        sidebar = _render_sidebar(user, selected)
        main_content = Observables.map(_render_iteration_detail, selected)

        # Update the browser tab title client-side whenever `selected` changes. The
        # static `<title>DearDiary</title>` below covers the landing page; subsequent
        # selections push a new title through the WebSocket without a re-render.
        title_text = Observables.map(_iteration_title, selected)
        Bonito.onjs(session, title_text, js"t => document.title = t")

        # Return explicit `<html>`/`<head>`/`<body>` so Bonito's `find_head_body` walker
        # locates this head and threads its session styles into it. With no explicit head,
        # Bonito auto-generates one and our favicon `<link>` ends up inside `<body>`,
        # where Firefox treats body-placed favicon links as a no-op.
        return Bonito.DOM.html(
            Bonito.DOM.head(
                Bonito.DOM.meta(; charset="UTF-8"),
                Bonito.DOM.meta(; name="viewport", content="width=device-width, initial-scale=1.0"),
                Bonito.DOM.title("DearDiary"),
                Bonito.DOM.link(; rel="icon", type="image/svg+xml", href=_FAVICON_ASSET),
                Bonito.DOM.style(_UI_STYLES),
            ),
            Bonito.DOM.body(
                Bonito.DOM.div(
                    sidebar,
                    Bonito.DOM.main(main_content; class="dd-main"),
                    ; class="dd-layout",
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
    .dd-error { background: #fef2f2; border: 1px solid #fecaca; color: #991b1b; padding: 0.75rem 1rem; border-radius: 0.375rem; font-family: ui-monospace, monospace; font-size: 0.85rem; white-space: pre-wrap; }
"""

function _render_sidebar(user, selected::Observables.Observable)
    project_blocks = Vector{Any}()
    for project in user |> get_projects
        push!(project_blocks, _render_project_block(project, selected))
    end
    brand = Bonito.DOM.div(
        Bonito.DOM.img(; src=_FAVICON_ASSET, alt="", class="dd-brand-logo"),
        Bonito.DOM.span("DearDiary"; class="dd-brand-text"),
        ; class="dd-brand",
    )
    footer = Bonito.DOM.div(
        Bonito.DOM.a(
            "Docs ↗";
            href="https://juliaai.github.io/DearDiary.jl/dev/",
            target="_blank",
            rel="noopener noreferrer",
            class="dd-docs-link",
        ),
        ; class="dd-sidebar-footer",
    )
    return Bonito.DOM.aside(
        brand,
        (project_blocks |> isempty) ?
            Bonito.DOM.p("No projects yet."; class="dd-empty") :
            Bonito.DOM.div(project_blocks...),
        footer,
        ; class="dd-sidebar",
    )
end

function _render_project_block(project, selected::Observables.Observable)
    experiment_blocks = [
        _render_experiment_block(experiment, selected)
        for experiment in project.id |> get_experiments
    ]
    return Bonito.DOM.div(
        Bonito.DOM.div(project.name; class="dd-project"),
        Bonito.DOM.ul(experiment_blocks...),
    )
end

function _render_experiment_block(experiment, selected::Observables.Observable)
    iterations = experiment.id |> get_iterations
    # Sort by id (creation order) and assign per-experiment ordinals. The sidebar
    # labels iterations as "Iteration 1, 2, 3..." within each experiment instead of
    # leaking the global database id. The canonical id stays visible in the detail
    # pane header for anyone who needs it.
    sorted_iters = sort(iterations; by=it -> it.id)
    ordinals = Dict{Int64,Int}(it.id => i for (i, it) in enumerate(sorted_iters))

    # Bucket children under their parent so the tree render can recurse one level at a
    # time. Top-level iterations (no `parent_iteration_id`) become the roots of the tree.
    children_by_parent = Dict{Int64,Vector{Iteration}}()
    top_level = Iteration[]
    for iteration in sorted_iters
        if iteration.parent_iteration_id |> isnothing
            push!(top_level, iteration)
        else
            push!(
                get!(children_by_parent, iteration.parent_iteration_id, Iteration[]),
                iteration,
            )
        end
    end

    iteration_items = [
        _render_iteration_node(iteration, children_by_parent, ordinals, selected)
        for iteration in top_level
    ]
    return Bonito.DOM.li(
        Bonito.DOM.div(experiment.name; class="dd-experiment"),
        Bonito.DOM.ul(iteration_items...),
    )
end

function _render_iteration_node(
    iteration::Iteration,
    children_by_parent::Dict{Int64,Vector{Iteration}},
    ordinals::Dict{Int64,Int},
    selected::Observables.Observable,
)
    children = get(children_by_parent, iteration.id, Iteration[])
    node_children = Any[_render_iteration_anchor(iteration, ordinals, selected)]
    if !(children |> isempty)
        child_nodes = [
            _render_iteration_node(child, children_by_parent, ordinals, selected)
            for child in children
        ]
        push!(node_children, Bonito.DOM.ul(child_nodes...))
    end
    return Bonito.DOM.li(node_children...)
end

function _render_iteration_anchor(
    iteration::Iteration,
    ordinals::Dict{Int64,Int},
    selected::Observables.Observable,
)
    status = iteration.status_id
    class = "dd-iter-link"
    if status == (RUNNING |> Integer)
        class *= " dd-iter-running"
    elseif status == (FAILED |> Integer)
        class *= " dd-iter-failed"
    elseif status == (KILLED |> Integer)
        class *= " dd-iter-killed"
    end
    ordinal = get(ordinals, iteration.id, 0)
    label = "$(_status_glyph(status)) Iteration $(ordinal) · $(_relative_time(iteration.created_date))"
    return Bonito.DOM.a(
        label;
        href="#",
        class=class,
        onclick=Bonito.js"event => {
            event.preventDefault();
            $(selected).notify($(iteration.id));
        }",
    )
end

function _iteration_title(iteration_id::Optional{<:Integer})::String
    if iteration_id |> isnothing
        return "DearDiary"
    end
    iteration = iteration_id |> get_iteration
    if iteration |> isnothing
        return "Iteration #$(iteration_id) not found · DearDiary"
    end
    experiment = iteration.experiment_id |> get_experiment
    experiment_name = (experiment |> isnothing) ? "?" : experiment.name
    return "#$(iteration.id) · $(experiment_name) · DearDiary"
end

function _render_iteration_detail(iteration_id::Optional{<:Integer})
    if iteration_id |> isnothing
        return Bonito.DOM.div(
            Bonito.DOM.p(
                "Pick an iteration from the sidebar to see its parameters, metrics, " *
                "and reproducibility metadata.";
                class="dd-empty",
            ),
        )
    end

    iteration = iteration_id |> get_iteration
    if iteration |> isnothing
        return Bonito.DOM.div(Bonito.DOM.p("Iteration $(iteration_id) not found."))
    end

    return Bonito.DOM.div(
        _render_iteration_header(iteration),
        _render_parameters_card(iteration),
        _render_metrics_card(iteration),
    )
end

function _render_iteration_header(iteration)
    badge_class, badge_text = _status_chrome(iteration.status_id)
    experiment = iteration.experiment_id |> get_experiment
    experiment_name = (experiment |> isnothing) ? "?" : experiment.name

    rows = Any[
        Bonito.DOM.h2("Iteration #$(iteration.id)"),
        Bonito.DOM.span(badge_text; class="dd-badge $badge_class"),
        Bonito.DOM.p(Bonito.DOM.b("Experiment: "), experiment_name; class="dd-meta"),
        Bonito.DOM.p(
            Bonito.DOM.b("Created: "), iteration.created_date |> string;
            class="dd-meta",
        ),
    ]
    if !(iteration.end_date |> isnothing)
        push!(rows, Bonito.DOM.p(
            Bonito.DOM.b("Ended: "), iteration.end_date |> string;
            class="dd-meta",
        ))
    end
    if !(iteration.parent_iteration_id |> isnothing)
        push!(rows, Bonito.DOM.p(
            Bonito.DOM.b("Parent iteration: "), "#$(iteration.parent_iteration_id)";
            class="dd-meta",
        ))
    end
    if !(iteration.error_message |> isempty)
        push!(rows, Bonito.DOM.div(iteration.error_message; class="dd-error"))
    end
    return Bonito.DOM.section(rows...; class="dd-card")
end

function _status_chrome(status_id::Integer)::Tuple{String,String}
    if status_id == (RUNNING |> Integer)
        return ("dd-badge-running", "running")
    elseif status_id == (SUCCEEDED |> Integer)
        return ("dd-badge-succeeded", "succeeded")
    elseif status_id == (FAILED |> Integer)
        return ("dd-badge-failed", "failed")
    elseif status_id == (KILLED |> Integer)
        return ("dd-badge-killed", "killed")
    end
    return ("dd-badge-running", "unknown")
end

function _status_glyph(status_id::Integer)::String
    status_id == (RUNNING |> Integer) && return "▶"
    status_id == (SUCCEEDED |> Integer) && return "✓"
    status_id == (FAILED |> Integer) && return "✗"
    status_id == (KILLED |> Integer) && return "⊘"
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
    params = iteration.id |> get_parameters
    body = (params |> isempty) ?
        Bonito.DOM.p("No parameters recorded."; class="dd-empty") :
        Bonito.DOM.table(
            Bonito.DOM.thead(Bonito.DOM.tr(
                Bonito.DOM.th("Key"), Bonito.DOM.th("Value"),
            )),
            Bonito.DOM.tbody([
                Bonito.DOM.tr(
                    Bonito.DOM.td(p.key), Bonito.DOM.td(p.value),
                ) for p in params
            ]...),
        )
    return Bonito.DOM.section(Bonito.DOM.h3("Parameters"), body; class="dd-card")
end

function _render_metrics_card(iteration)
    metrics = iteration.id |> get_metrics
    if metrics |> isempty
        return Bonito.DOM.section(
            Bonito.DOM.h3("Metrics"),
            Bonito.DOM.p("No metrics recorded."; class="dd-empty"),
            ; class="dd-card",
        )
    end
    return Bonito.DOM.section(
        Bonito.DOM.h3("Metrics"),
        _build_metrics_figure(metrics),
        ; class="dd-card",
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
    "#4e79a7", "#f28e2c", "#e15759", "#76b7b2", "#59a14f",
    "#edc949", "#af7aa1", "#ff9da7", "#9c755f", "#bab0ab",
]

_chart_color(idx::Integer) = _CHART_COLORS[((idx - 1) % length(_CHART_COLORS)) + 1]

_scale_x(x::Real, x_min::Real, x_max::Real, plot_w::Real) =
    x_max == x_min ? plot_w / 2 : (x - x_min) / (x_max - x_min) * plot_w

_scale_y(y::Real, y_min::Real, y_max::Real, plot_h::Real) =
    y_max == y_min ? plot_h / 2 : plot_h - (y - y_min) / (y_max - y_min) * plot_h

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
    # Render the chart as inline SVG. No external JS bundle, no client-side render
    # pipeline: the response bytes are ready to paint as soon as they reach the
    # browser. Hover tooltips ride on each `<circle>`'s `<title>` child, which
    # browsers surface as a native tooltip without any script support.
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
        push!(axis_elements, Bonito.SVG.line(;
            x1=0, x2=plot_w, y1=py, y2=py, stroke="#e4e7eb", strokeWidth=1,
        ))
        push!(axis_elements, Bonito.SVG.text(_format_tick(y);
            x=-8, y=py + 4, fill="#52606d", fontSize=11, textAnchor="end",
        ))
    end
    for x in _tick_values_x(x_min, x_max)
        px = _scale_x(x, x_min, x_max, plot_w)
        push!(axis_elements, Bonito.SVG.text(string(x);
            x=px, y=plot_h + 18, fill="#52606d", fontSize=11, textAnchor="middle",
        ))
    end
    push!(axis_elements, Bonito.SVG.line(;
        x1=0, x2=plot_w, y1=plot_h, y2=plot_h, stroke="#cbd2d9", strokeWidth=1,
    ))
    push!(axis_elements, Bonito.SVG.line(;
        x1=0, x2=0, y1=0, y2=plot_h, stroke="#cbd2d9", strokeWidth=1,
    ))
    push!(axis_elements, Bonito.SVG.text("step";
        x=plot_w / 2, y=plot_h + 38, fill="#52606d", fontSize=12, textAnchor="middle",
    ))
    push!(axis_elements, Bonito.SVG.text("value";
        x=-44, y=plot_h / 2, fill="#52606d", fontSize=12, textAnchor="middle",
        transform="rotate(-90 -44 $(plot_h / 2))",
    ))

    series_keys = sort(collect(keys(grouped)))
    series_elements = Any[]
    for (i, key) in enumerate(series_keys)
        color = _chart_color(i)
        points = grouped[key]
        points_str = join(
            ("$(_scale_x(x, x_min, x_max, plot_w)),$(_scale_y(y, y_min, y_max, plot_h))"
             for (x, y) in points),
            " ",
        )
        push!(series_elements, Bonito.SVG.polyline(;
            points=points_str, stroke=color, fill="none", strokeWidth=2,
        ))
        # Hyperscript treats `<circle>` as void, so the tooltip lives on a sibling
        # `<title>` inside a per-point `<g>`. Browsers surface the group's title on
        # hover anywhere within its bounding box.
        point_groups = Any[
            Bonito.SVG.g(
                Bonito.SVG.title("$(key): step $(x), value $(_format_tick(y))"),
                Bonito.SVG.circle(;
                    cx=_scale_x(x, x_min, x_max, plot_w),
                    cy=_scale_y(y, y_min, y_max, plot_h),
                    r=3, fill=color,
                ),
            ) for (x, y) in points
        ]
        push!(series_elements, Bonito.SVG.g(point_groups...))
    end

    legend_elements = Any[]
    legend_x = 0.0
    for (i, key) in enumerate(series_keys)
        color = _chart_color(i)
        push!(legend_elements, Bonito.SVG.circle(;
            cx=legend_x + 6, cy=-14, r=4, fill=color,
        ))
        push!(legend_elements, Bonito.SVG.text(key;
            x=legend_x + 16, y=-10, fill="#1f2933", fontSize=11,
        ))
        legend_x += 22 + length(key) * 7
    end

    return Bonito.SVG.svg(
        Bonito.SVG.g(
            axis_elements..., series_elements..., legend_elements...;
            transform="translate($(_MARGIN_L),$(_MARGIN_T))",
        );
        viewBox="0 0 $(_CHART_W) $(_CHART_H)",
        xmlns="http://www.w3.org/2000/svg",
        style="width:100%;height:380px;display:block;",
    )
end
