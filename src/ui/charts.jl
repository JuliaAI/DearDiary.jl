# Ten series colours tuned to read on both the paper and ink themes. Series beyond the
# tenth wrap around.
const _SERIES_COLORS = [
    "#4a7aa6",
    "#b85c5a",
    "#5f9a5e",
    "#c08f2b",
    "#8a6a9c",
    "#3e8f8a",
    "#c76f3b",
    "#8a9a3c",
    "#c0607f",
    "#6c7c8f",
]

_series_color(idx::Integer)::String = _SERIES_COLORS[mod1(idx, length(_SERIES_COLORS))]

# JSON has no NaN or Inf; the client skips null samples.
_json_value(v::Real) = isfinite(v) ? Float64(v) : nothing

function _chart_series(
    name::AbstractString, color::AbstractString, points; href=nothing, labels=nothing
)
    encoded = Vector{Any}(undef, length(points))
    for (i, (x, y)) in enumerate(points)
        encoded[i] = if isnothing(labels)
            Any[x, _json_value(y)]
        else
            Any[x, _json_value(y), labels[i]]
        end
    end
    series = Dict{String,Any}(
        "name" => String(name), "color" => String(color), "points" => encoded
    )
    isnothing(href) || (series["href"] = String(href))
    return series
end

function _chart_payload(
    title::AbstractString,
    series::AbstractVector;
    type::AbstractString="line",
    xlabel::AbstractString="step",
    height::Integer=240,
    legend::Bool=false,
    xprefix::Optional{AbstractString}=nothing,
)::String
    spec = Dict{String,Any}(
        "title" => String(title),
        "type" => String(type),
        "xlabel" => String(xlabel),
        "height" => Int(height),
        "legend" => legend,
        "series" => series,
    )
    isnothing(xprefix) || (spec["xprefix"] = String(xprefix))
    return JSON.json(spec)
end

function _chart_node(
    payload::AbstractString, title::AbstractString; sub::Optional{AbstractString}=nothing
)
    head = DOM.div(
        DOM.span(title; class="dd-chart-title"),
        isnothing(sub) ? nothing : DOM.span(sub; class="dd-chart-sub");
        class="dd-chart-head",
    )
    return DOM.div(head; class="dd-chart", dataChart=payload)
end

"""
    _iteration_charts(metrics)::Vector

One line chart per metric key that was logged at more than one step. Keys logged once are
summarised in the metric tiles instead, since a single point makes a poor line.
"""
function _iteration_charts(metrics::AbstractVector{Metric})::Vector{Any}
    grouped = _series(metrics)
    charts = Any[]
    keys_sorted = sort(collect(keys(grouped)))
    for (i, key) in enumerate(keys_sorted)
        points = grouped[key]
        length(points) < 2 && continue
        series = [_chart_series(key, _series_color(i), points)]
        payload = _chart_payload(key, series)
        push!(charts, _chart_node(payload, key; sub=_pluralize(length(points), "step")))
    end
    return charts
end

const _MAX_CHARTED_ITERATIONS = 40

"""
    _experiment_charts(rows)::Vector

One chart per metric key across the experiment's iterations. When every iteration logged
the key once, the chart is a scatter of final values by ordinal; otherwise each iteration
becomes a line. Only the most recent `_MAX_CHARTED_ITERATIONS` iterations are plotted.
"""
function _experiment_charts(rows::AbstractVector{IterationRow})::Vector{Any}
    charted = if length(rows) > _MAX_CHARTED_ITERATIONS
        last(sort(rows; by=r -> r.ordinal), _MAX_CHARTED_ITERATIONS)
    else
        rows
    end
    charts = Any[]
    for (i, key) in enumerate(_metric_keys(rows))
        with_key = [
            r for r in charted if haskey(r.metrics, key) && !isempty(r.metrics[key])
        ]
        isempty(with_key) && continue
        single_valued = all(r -> length(r.metrics[key]) == 1, with_key)
        if single_valued
            points = [(r.ordinal, last(r.metrics[key])[2]) for r in with_key]
            labels = ["Iteration $(r.ordinal)" for r in with_key]
            series = [_chart_series(key, _series_color(i), points; labels=labels)]
            payload = _chart_payload(
                key, series; type="scatter", xlabel="iteration", xprefix="#"
            )
            sub = "final value · $(_pluralize(length(with_key), "iteration"))"
        else
            series = [
                _chart_series(
                    "Iteration $(r.ordinal)",
                    _series_color(r.ordinal),
                    r.metrics[key];
                    href=_iteration_url(r.iteration.id),
                ) for r in with_key
            ]
            payload = _chart_payload(key, series; legend=true, height=260)
            sub = _pluralize(length(with_key), "iteration")
        end
        push!(charts, _chart_node(payload, key; sub=sub))
    end
    return charts
end

function _sparkline(values::AbstractVector{<:Real}, color::AbstractString)
    payload = JSON.json([_json_value(v) for v in values])
    return DOM.div(; dataSpark=payload, dataSparkColor=color)
end
