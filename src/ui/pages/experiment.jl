const _ITERATION_SNIPPET = """
with_iteration(client, experiment_id) do iter
    create_parameter(client, iter.id, "max_depth", 7)
    for epoch in 1:20
        create_metric(client, iter.id, "loss", 1 / epoch; step=epoch)
    end
end"""

function _render_experiment(experiment::Experiment, ctx::PageContext)::Page
    project = get_project(experiment.project_id)
    summary = _experiment_summary(experiment)
    access = _access(ctx.viewer, experiment.project_id)
    rows = _iteration_rows(summary.iterations)
    resources = get_resources(experiment.id)
    running = _count(summary.counts, RUNNING)
    duration = if isnothing(experiment.end_date)
        nothing
    else
        experiment.end_date - experiment.created_date
    end

    crumbs = Any["Projects" => "/"]
    isnothing(project) || push!(crumbs, project.name => _project_url(project.id))
    push!(crumbs, experiment.name => nothing)

    editors = _experiment_editors(ctx, experiment, access, summary.tags)
    hero = _hero(;
        title=editors.title,
        lede=editors.lede,
        lede_empty="No description yet.",
        meta=_meta(
            editors.status,
            _meta_item("Created ", _format_datetime(experiment.created_date)),
            if isnothing(experiment.end_date)
                nothing
            else
                _meta_item("Ended ", _format_datetime(experiment.end_date))
            end,
            if isnothing(duration)
                nothing
            else
                _meta_item("Duration ", _format_duration(duration))
            end,
            _id_chip(experiment.id),
        ),
        tags=editors.tags,
        actions=Any[running > 0 ? _live_pill() : nothing, editors.menu],
    )
    stats = _stats(
        _stat("Iterations", length(summary.iterations)),
        _stat("Succeeded", _count(summary.counts, SUCCEEDED)),
        _stat("Failed", _count(summary.counts, FAILED)),
        _stat("Running", running),
        _stat("Artifacts", length(resources)),
        _stat(
            "Last activity",
            isnothing(summary.last_activity) ? "–" : _relative_time(summary.last_activity);
            sub=(
                if isnothing(summary.last_activity)
                    nothing
                else
                    _format_datetime(summary.last_activity)
                end
            ),
        );
    )

    iterations_body = if isempty(rows)
        _empty(
            "No iterations yet.",
            "An iteration is one training run or evaluation job. Open one under this experiment:";
            snippet=_ITERATION_SNIPPET,
        )
    else
        _iterations_table(rows)
    end
    iterations_section = _section(
        "Iterations",
        iterations_body;
        count=length(rows),
        tools=(isempty(rows) ? nothing : _filter("iterations", "Filter iterations")),
        note=(
            if isempty(rows)
                nothing
            else
                "Click a column to sort. Parameters and final metric values are shown per iteration; child iterations sit under their parent."
            end
        ),
    )

    charts = _experiment_charts(rows)
    metrics_body = if isempty(charts)
        _empty(
            "No metrics logged.",
            "Metric series logged on these iterations will be compared here.",
        )
    else
        DOM.div(charts...; class="dd-charts")
    end
    metrics_note = if length(rows) > _MAX_CHARTED_ITERATIONS
        "Showing the most recent $(_MAX_CHARTED_ITERATIONS) iterations. Hover a chart for values; click a legend entry to hide a series, or a line to open its iteration."
    elseif !isempty(charts)
        "Hover a chart for values. Click a legend entry to hide a series, or a line to open its iteration."
    else
        nothing
    end
    metrics_section = _section(
        "Metrics across iterations", metrics_body; count=length(charts), note=metrics_note
    )

    artifacts_body = if isempty(resources)
        _empty(
            "No artifacts stored.",
            "Files attached to this experiment with create_resource appear here with a download link.",
        )
    else
        _resources_table(resources)
    end
    artifacts_section = _section("Artifacts", artifacts_body; count=length(resources))

    return Page(
        "$(experiment.name) · DearDiary",
        crumbs,
        Any[
            hero, _flash(ctx), stats, iterations_section, metrics_section, artifacts_section
        ];
        live=(running > 0),
    )
end

function _iterations_table(rows::AbstractVector{IterationRow})
    param_keys = _parameter_keys(rows)
    metric_keys = _metric_keys(rows)
    fixed = ["#", "Status", "Started", "Duration"]
    trailing = ["Tags", "Notes"]
    n_fixed = length(fixed)
    n_params = length(param_keys)
    n_metrics = length(metric_keys)
    has_groups = n_params + n_metrics > 0

    top = Any[
        _th(
            "#";
            sort="num",
            col=0,
            rowspan=(has_groups ? 2 : nothing),
            class="dd-col-sticky",
        ),
        _th("Status"; sort="text", col=1, rowspan=(has_groups ? 2 : nothing)),
        _th("Started"; sort="num", col=2, rowspan=(has_groups ? 2 : nothing)),
        _th(
            "Duration";
            sort="num",
            col=3,
            rowspan=(has_groups ? 2 : nothing),
            class="dd-num",
        ),
    ]
    n_params > 0 && push!(top, _th("Parameters"; colspan=n_params, class="dd-group"))
    n_metrics > 0 && push!(top, _th("Metrics"; colspan=n_metrics, class="dd-group"))
    tags_col = n_fixed + n_params + n_metrics
    push!(
        top,
        _th(
            "Tags";
            rowspan=(has_groups ? 2 : nothing),
            class=(has_groups ? "dd-group-start" : nothing),
        ),
    )
    push!(
        top, _th("Notes"; sort="text", col=tags_col + 1, rowspan=(has_groups ? 2 : nothing))
    )

    head_rows = Any[DOM.tr(top...)]
    if has_groups
        second = Any[]
        for (i, key) in enumerate(param_keys)
            push!(
                second,
                _th(
                    key;
                    sort="num",
                    col=n_fixed + i - 1,
                    class=(i == 1 ? "dd-group-start dd-mono" : "dd-mono"),
                    title=key,
                ),
            )
        end
        for (i, key) in enumerate(metric_keys)
            push!(
                second,
                _th(
                    key;
                    sort="num",
                    col=n_fixed + n_params + i - 1,
                    class=(i == 1 ? "dd-group-start dd-num dd-mono" : "dd-num dd-mono"),
                    title=key,
                ),
            )
        end
        push!(head_rows, DOM.tr(second...))
    end

    body_rows = Any[]
    for row in rows
        it = row.iteration
        ordinal_link = _link(
            DOM.span("#$(row.ordinal)"; class="dd-ordinal"),
            _iteration_url(it.id);
            class="dd-row-link",
        )
        cells = Any[
            _td(
                ordinal_link,
                _child_mark(row.parent_ordinal);
                class="dd-col-sticky",
                value=row.ordinal,
            ),
            _td(
                _iteration_badge(it.status_id); value=_iteration_status(it.status_id).label
            ),
            _time_cell(it.created_date),
            _duration_cell(_duration(it)),
        ]
        for (i, key) in enumerate(param_keys)
            prefix = i == 1 ? "dd-group-start " : ""
            push!(cells, _parameter_cell(get(row.parameters, key, nothing), prefix))
        end
        for (i, key) in enumerate(metric_keys)
            prefix = i == 1 ? "dd-group-start " : ""
            push!(cells, _metric_cell(_final_value(row, key), prefix))
        end
        push!(
            cells,
            _td(_tag_chips(row.tags); class=(has_groups ? "dd-group-start" : nothing)),
        )
        push!(cells, _notes_cell(it.notes))
        push!(
            body_rows,
            DOM.tr(cells...; _attrs(; class=(row.depth > 0 ? "dd-row-child" : nothing))...),
        )
    end
    return _table(head_rows, body_rows; id="iterations")
end

function _resources_table(resources::AbstractVector{Resource})
    head = DOM.tr(
        _th("Artifact"; sort="text"),
        _th("Description"),
        _th("Size"; sort="num", class="dd-num"),
        _th("Backend"; sort="text"),
        _th("SHA-256"),
        _th("Stored"; sort="num"),
        _th("Updated"; sort="num"),
        _th(DOM.span("Actions"; class="dd-sr-only")),
    )
    rows = [
        DOM.tr(
            _td(_link(r.name, _download_url(r.id); class="dd-row-link"); title=r.uri),
            _td(
                isempty(r.description) ? "–" : _truncate(r.description, 90);
                class=(isempty(r.description) ? "dd-dim" : "dd-wrap"),
                title=r.description,
            ),
            _td(_format_bytes(r.size_bytes); class="dd-num", value=r.size_bytes),
            _td(r.backend; class="dd-mono"),
            _td(
                if isempty(r.content_hash)
                    "–"
                else
                    DOM.span(
                        DOM.code(_short_sha(r.content_hash)),
                        _copy_button(r.content_hash);
                        class="dd-id",
                    )
                end;
                class=(isempty(r.content_hash) ? "dd-dim" : nothing),
                title=r.content_hash,
            ),
            _time_cell(r.created_date),
            _time_cell(r.updated_date),
            _td(
                DOM.a(
                    _download_icon(),
                    "Download";
                    href=_download_url(r.id),
                    class="dd-action",
                );
                class="dd-right",
            ),
        ) for r in resources
    ]
    return _table([head], rows; id="artifacts")
end
