const _SNAPSHOT_SNIPPET = """
# Capture Manifest.toml, the Julia version, and the git SHA on the running iteration.
snapshot_environment!(client, iteration_id)"""

function _render_iteration(iteration::Iteration, ctx::PageContext)::Page
    experiment = get_experiment(iteration.experiment_id)
    project = isnothing(experiment) ? nothing : get_project(experiment.project_id)
    ordinal = _iteration_ordinal(iteration)
    running = iteration.status_id == Integer(RUNNING)
    parameters = get_parameters(iteration.id)
    metrics = get_metrics(iteration.id)
    summaries = _metric_summaries(metrics)
    tags = get_tags(Iteration, iteration.id)
    children = get_child_iterations(iteration.id)
    parent = if isnothing(iteration.parent_iteration_id)
        nothing
    else
        get_iteration(iteration.parent_iteration_id)
    end
    versions = if isnothing(project)
        Tuple{Model,ModelVersion}[]
    else
        _versions_for_iteration(project.id, iteration.id)
    end
    duration = _duration(iteration)
    access = _access(ctx.viewer, isnothing(project) ? nothing : project.id)
    title = "Iteration $(ordinal)"

    crumbs = Any["Projects" => "/"]
    isnothing(project) || push!(crumbs, project.name => _project_url(project.id))
    isnothing(experiment) ||
        push!(crumbs, experiment.name => _experiment_url(experiment.id))
    push!(crumbs, title => nothing)

    editors = _iteration_editors(ctx, iteration, ordinal, access, tags)
    hero = _hero(;
        title=title,
        meta=_meta(
            _iteration_badge(iteration.status_id; large=true),
            editors.lock,
            _meta_item("Started ", _format_datetime(iteration.created_date)),
            if isnothing(iteration.end_date)
                nothing
            else
                _meta_item("Ended ", _format_datetime(iteration.end_date))
            end,
            if isnothing(duration)
                nothing
            else
                _meta_item("Duration ", _format_duration(duration))
            end,
            _id_chip(iteration.id),
        ),
        tags=editors.tags,
        actions=Any[running ? _live_pill() : nothing, editors.menu],
    )

    body = Any[hero, _flash(ctx)]
    isempty(iteration.error_message) || push!(
        body,
        DOM.div(
            _note(iteration.error_message; label="Error", error=true);
            class="dd-section",
        ),
    )
    isnothing(editors.notes) || push!(body, DOM.div(editors.notes; class="dd-section"))

    push!(body, _metrics_section(summaries, metrics))
    push!(body, _parameters_section(parameters))
    lineage = _lineage_section(iteration, ordinal, parent, children)
    isnothing(lineage) || push!(body, lineage)
    registry = _registry_section(versions)
    isnothing(registry) || push!(body, registry)
    push!(body, _environment_section(iteration))

    tab_title = if isnothing(experiment)
        "$(title) · DearDiary"
    else
        "$(title) · $(experiment.name) · DearDiary"
    end
    return Page(tab_title, crumbs, body; live=running)
end

function _metric_tile(summary::MetricSummary, index::Integer)
    color = _series_color(index)
    sub = if summary.count == 1
        "logged once"
    else
        "$(_pluralize(summary.count, "step")) · min $(_format_number(summary.min)) · max $(_format_number(summary.max))"
    end
    return DOM.div(
        DOM.div(
            DOM.span(; class="dd-swatch", style="background: $(color)"),
            summary.key;
            class="dd-tile-key",
            title=summary.key,
        ),
        DOM.div(
            _format_number(summary.last); class="dd-tile-value", title=string(summary.last)
        ),
        DOM.div(sub; class="dd-tile-sub"),
        summary.count > 1 ? _sparkline(summary.values, color) : nothing;
        class="dd-tile",
    )
end

function _metrics_section(
    summaries::AbstractVector{MetricSummary}, metrics::AbstractVector{Metric}
)
    if isempty(summaries)
        return _section(
            "Metrics",
            _empty(
                "No metrics recorded.",
                "Values logged with create_metric or log_metrics show up here as tiles and, for series, as charts.",
            );
            count=0,
        )
    end
    tiles = DOM.div(
        (_metric_tile(s, i) for (i, s) in enumerate(summaries))...; class="dd-tiles"
    )
    charts = _iteration_charts(metrics)
    children = Any[tiles]
    if !isempty(charts)
        push!(children, DOM.div(charts...; class="dd-charts", style="margin-top: 16px"))
    end
    note = if isempty(charts)
        nothing
    else
        "Latest value per metric. Hover a chart for the value at each step."
    end
    return _section("Metrics", children...; count=length(summaries), note=note)
end

function _parameters_section(parameters::AbstractVector{Parameter})
    body = if isempty(parameters)
        _empty(
            "No parameters recorded.",
            "Hyperparameters logged with create_parameter are listed here.",
        )
    else
        _card(_kv([(p.key, p.value) for p in sort(parameters; by=p -> p.key)]))
    end
    return _section("Parameters", body; count=length(parameters))
end

function _lineage_section(
    iteration::Iteration,
    ordinal::Integer,
    parent::Optional{Iteration},
    children::AbstractVector{Iteration},
)
    isnothing(parent) &&
        isempty(children) &&
        isnothing(iteration.parent_iteration_id) &&
        return nothing
    rows = Any[]
    if !isnothing(parent)
        push!(
            rows,
            _lineage_row(
                "Parent",
                DOM.span(
                    _link(
                        "Iteration $(_iteration_ordinal(parent))", _iteration_url(parent.id)
                    ),
                    " ",
                    _iteration_badge(parent.status_id),
                ),
                _relative_time(parent.created_date),
            ),
        )
    elseif !isnothing(iteration.parent_iteration_id)
        push!(
            rows, _lineage_row("Parent", DOM.span("Deleted iteration"; class="dd-dim"), "")
        )
    end
    push!(
        rows,
        _lineage_row(
            "This",
            DOM.span("Iteration $(ordinal) ", _iteration_badge(iteration.status_id)),
            _relative_time(iteration.created_date);
            current=true,
        ),
    )
    ordinals = if isempty(children)
        Dict{String,Int}()
    else
        _ordinals(get_iterations(iteration.experiment_id))
    end
    for child in children
        push!(
            rows,
            _lineage_row(
                "Child",
                DOM.span(
                    _link(
                        "Iteration $(get(ordinals, child.id, 0))", _iteration_url(child.id)
                    ),
                    " ",
                    _iteration_badge(child.status_id),
                ),
                _relative_time(child.created_date),
            ),
        )
    end
    note = if isempty(children)
        nothing
    else
        "Child iterations are trials, folds, or workers spawned from this one."
    end
    return _section(
        "Lineage", DOM.div(rows...; class="dd-lineage"); count=length(children), note=note
    )
end

function _registry_section(versions::AbstractVector{Tuple{Model,ModelVersion}})
    isempty(versions) && return nothing
    head = DOM.tr(
        _th("Model"; sort="text"),
        _th("Version"; sort="num"),
        _th("Stage"),
        _th("Description"),
        _th("Registered"; sort="num"),
    )
    rows = [
        DOM.tr(
            _td(_link(model.name, _model_url(model.id); class="dd-row-link")),
            _td("v$(version.version)"; class="dd-mono", value=version.version),
            _td(_stage_badge(version.stage_id)),
            _td(
                isempty(version.description) ? "–" : version.description;
                class=(isempty(version.description) ? "dd-dim" : "dd-wrap"),
            ),
            _time_cell(version.created_date),
        ) for (model, version) in versions
    ]
    return _section(
        "Model registry",
        _table([head], rows; id="registry");
        count=length(versions),
        note="Model versions registered from this iteration.",
    )
end

function _environment_section(iteration::Iteration)
    has_snapshot =
        !isempty(iteration.julia_version) ||
        !isempty(iteration.git_sha) ||
        !isempty(iteration.entrypoint) ||
        !isempty(iteration.manifest_toml)
    if !has_snapshot
        return _section(
            "Environment",
            _empty(
                "No environment captured.",
                "Snapshots record the Julia version, git commit, entrypoint, and the exact Manifest.toml so the run can be rebuilt later. Child iterations inherit their parent's snapshot.";
                snippet=_SNAPSHOT_SNIPPET,
            );
        )
    end
    git = if isempty(iteration.git_sha)
        DOM.span("not in a git repository"; class="dd-dim")
    else
        DOM.span(
            DOM.code(iteration.git_sha),
            " ",
            if iteration.git_dirty
                _badge((tone="ochre", label="dirty tree"))
            else
                _badge((tone="sage", label="clean tree"))
            end,
        )
    end
    pairs = Any[
        (
            "Julia",
            if isempty(iteration.julia_version)
                DOM.span("–"; class="dd-dim")
            else
                iteration.julia_version
            end,
        ),
        ("Git commit", git),
        (
            "Entrypoint",
            if isempty(iteration.entrypoint)
                DOM.span("REPL session"; class="dd-dim")
            else
                iteration.entrypoint
            end,
        ),
    ]
    children = Any[_card(_kv(pairs))]
    if !isempty(iteration.manifest_toml)
        push!(
            children,
            DOM.div(
                DOM.p(
                    "Rebuild this environment in a fresh directory:";
                    class="dd-small dd-dim",
                    style="margin: 16px 0 6px",
                ),
                _code(
                    "using DearDiary\nDearDiary.restore(\"$(iteration.id)\")"; inline=true
                ),
            ),
        )
    end
    isempty(iteration.project_toml) || push!(
        children,
        _fold(
            "Project.toml",
            _code(iteration.project_toml);
            meta=_pluralize(_line_count(iteration.project_toml), "line"),
        ),
    )
    isempty(iteration.manifest_toml) || push!(
        children,
        _fold(
            "Manifest.toml",
            _code(iteration.manifest_toml);
            meta=_pluralize(_line_count(iteration.manifest_toml), "line"),
        ),
    )
    return _section(
        "Environment",
        children...;
        note="Captured at snapshot time so the iteration can be reproduced.",
    )
end
