const _EXPERIMENT_SNIPPET = """
experiment_id = create_experiment(
    client, project_id, DearDiary.IN_PROGRESS, "Decision-tree sweep"
)"""

const _MODEL_SNIPPET = """
model_id = create_model(client, project_id, "iris-classifier")
version_id = create_modelversion(client, model_id, iteration_id; description="first cut")"""

function _render_project(project::Project, ctx::PageContext)::Page
    summary = _project_summary(project)
    counts = _status_counts(summary)
    n_iterations = _iteration_count(summary)
    last_activity = _last_activity(summary)

    crumbs = Any["Projects" => "/", project.name => nothing]
    editors = _project_editors(ctx, project, summary.tags)
    hero = _hero(;
        title=editors.title,
        lede=editors.lede,
        lede_empty="No description yet.",
        meta=_meta(
            _meta_item("Created ", _format_date(project.created_date)), _id_chip(project.id)
        ),
        tags=editors.tags,
        actions=editors.menu,
    )
    stats = _stats(
        _stat("Experiments", length(summary.experiments)),
        _stat("Iterations", n_iterations),
        _stat("Succeeded", _count(counts, SUCCEEDED)),
        _stat("Failed", _count(counts, FAILED)),
        _stat("Models", length(summary.models)),
        _stat(
            "Last activity",
            isnothing(last_activity) ? "–" : _relative_time(last_activity);
            sub=(isnothing(last_activity) ? nothing : _format_datetime(last_activity)),
        );
    )

    experiments = if isempty(summary.experiments)
        _empty(
            "No experiments yet.",
            "Experiments group related iterations. Create one under this project:";
            snippet=_EXPERIMENT_SNIPPET,
        )
    else
        _experiments_table(summary.experiments)
    end
    experiments_section = _section(
        "Experiments",
        experiments;
        count=length(summary.experiments),
        tools=(
            if isempty(summary.experiments)
                nothing
            else
                _filter("experiments", "Filter experiments")
            end
        ),
    )

    models = if isempty(summary.models)
        _empty(
            "No registered models.",
            "Register a model and version checkpoints from the iterations that produced them:";
            snippet=_MODEL_SNIPPET,
        )
    else
        _models_table(summary.models)
    end
    models_section = _section(
        "Model registry",
        models;
        count=length(summary.models),
        tools=(isempty(summary.models) ? nothing : _filter("models", "Filter models")),
    )

    return Page(
        "$(project.name) · DearDiary",
        crumbs,
        Any[hero, _flash(ctx), stats, experiments_section, models_section],
    )
end

function _experiments_table(experiments::AbstractVector{ExperimentSummary})
    head = DOM.tr(
        _th("Experiment"; sort="text"),
        _th("Status"; sort="text"),
        _th("Iterations"; sort="num", class="dd-num"),
        _th("Outcomes"),
        _th("Last activity"; sort="num"),
        _th("Created"; sort="num"),
        _th("Tags"),
    )
    rows = [
        DOM.tr(
            _td(
                _link(
                    e.experiment.name, _experiment_url(e.experiment.id); class="dd-row-link"
                ),
                _description_line(e.experiment.description);
                class="dd-wrap",
            ),
            _td(
                _experiment_badge(e.experiment.status_id);
                value=_experiment_status(e.experiment.status_id).label,
            ),
            _td(string(length(e.iterations)); class="dd-num", value=length(e.iterations)),
            _td(_statusbar(e.counts)),
            _time_cell(e.last_activity),
            _time_cell(e.experiment.created_date),
            _td(_tag_chips(e.tags)),
        ) for e in experiments
    ]
    return _table([head], rows; id="experiments")
end

function _models_table(models::AbstractVector{Model})
    head = DOM.tr(
        _th("Model"; sort="text"),
        _th("Description"),
        _th("Versions"; sort="num", class="dd-num"),
        _th("Production"; sort="text"),
        _th("Latest stage"),
        _th("Registered"; sort="num"),
        _th("Updated"; sort="num"),
    )
    rows = Any[]
    for model in models
        versions = get_modelversions(model.id)
        production = _production_version(versions)
        latest = isempty(versions) ? nothing : versions[argmax(v.version for v in versions)]
        push!(
            rows,
            DOM.tr(
                _td(_link(model.name, _model_url(model.id); class="dd-row-link")),
                _td(
                    isempty(model.description) ? "–" : _truncate(model.description, 90);
                    class=(isempty(model.description) ? "dd-dim" : "dd-wrap"),
                    title=model.description,
                ),
                _td(string(length(versions)); class="dd-num", value=length(versions)),
                _td(
                    isnothing(production) ? "–" : "v$(production.version)";
                    class=(isnothing(production) ? "dd-dim" : "dd-mono"),
                    value=(isnothing(production) ? "" : production.version),
                ),
                _td(
                    if isnothing(latest)
                        DOM.span("–"; class="dd-dim")
                    else
                        _stage_badge(latest.stage_id)
                    end,
                ),
                _time_cell(model.created_date),
                _time_cell(model.updated_date),
            ),
        )
    end
    return _table([head], rows; id="models")
end
