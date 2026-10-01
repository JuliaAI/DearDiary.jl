const _WELCOME_SNIPPET = """
using DearDiary

client = DearDiary.connect("http://127.0.0.1:9000")

project_id = create_project(client, "Iris classification")
experiment_id = create_experiment(
    client, project_id, DearDiary.IN_PROGRESS, "Decision-tree sweep"
)

with_iteration(client, experiment_id) do iter
    create_parameter(client, iter.id, "max_depth", 7)
    create_metric(client, iter.id, "accuracy", 0.96)
end"""

function _render_home(viewer::User)::Page
    summaries = [_project_summary(p) for p in get_projects(viewer)]
    n_experiments = sum(length(s.experiments) for s in summaries; init=0)
    n_iterations = sum(_iteration_count(s) for s in summaries; init=0)
    n_models = sum(length(s.models) for s in summaries; init=0)
    counts = Dict{Int64,Int}()
    for s in summaries
        for (status, n) in _status_counts(s)
            counts[status] = get(counts, status, 0) + n
        end
    end
    succeeded = _count(counts, SUCCEEDED)
    failed = _count(counts, FAILED)
    running = _count(counts, RUNNING)

    hero = _hero(;
        title="Projects",
        lede="Every project, experiment, and iteration recorded in this store.",
    )

    body = Any[hero]
    if isempty(summaries)
        push!(body, _welcome())
    else
        push!(
            body,
            _stats(
                _stat("Projects", length(summaries)),
                _stat("Experiments", n_experiments),
                _stat(
                    "Iterations",
                    n_iterations;
                    sub=(
                        if n_iterations == 0
                            nothing
                        else
                            "$(succeeded) succeeded · $(failed) failed"
                        end
                    ),
                ),
                _stat("Running now", running),
                _stat("Registered models", n_models);
            ),
        )
        cards = [_project_card(s, i + 1) for (i, s) in enumerate(summaries)]
        push!(
            body,
            _section(
                "Projects", DOM.div(cards...; class="dd-grid"); count=length(summaries)
            ),
        )
    end
    return Page("Projects · DearDiary", Any[], body)
end

function _welcome()
    return DOM.section(
        DOM.div(
            DOM.h2("A blank notebook."),
            DOM.p(
                "Nothing has been recorded yet. Log a project from Julia through the REST " *
                "client, or directly against the database with the offline API, and it " *
                "will show up here.",
            ),
            DOM.p(
                _external_link(
                    "Read the quickstart", "$(_DOCS_URL)getting-started/quickstart/"
                ),
            ),
        ),
        _code(_WELCOME_SNIPPET; inline=true);
        class="dd-welcome",
    )
end

function _project_card(summary::ProjectSummary, index::Integer)
    project = summary.project
    n_iterations = _iteration_count(summary)
    last_activity = _last_activity(summary)
    description = if isempty(project.description)
        DOM.p("No description yet."; class="dd-muted")
    else
        DOM.p(project.description)
    end
    return DOM.a(
        DOM.h3(project.name),
        description,
        _tag_chips(summary.tags),
        DOM.div(
            DOM.span(DOM.b(string(length(summary.experiments))), " experiments"),
            DOM.span(DOM.b(string(n_iterations)), " iterations"),
            DOM.span(DOM.b(string(length(summary.models))), " models");
            class="dd-card-stats",
        ),
        DOM.div(
            DOM.span("Created $(_format_date(project.created_date))"),
            DOM.span(
                if isnothing(last_activity)
                    "No iterations yet"
                else
                    "Active $(_relative_time(last_activity))"
                end,
            );
            class="dd-card-foot",
        );
        href=_project_url(project.id),
        class="dd-card dd-project-card",
    )
end
