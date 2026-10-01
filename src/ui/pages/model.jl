function _render_model(model::Model, ctx::PageContext)::Page
    project = get_project(model.project_id)
    versions = sort(get_modelversions(model.id); by=v -> v.version, rev=true)
    production = _production_version(versions)
    access = _access(ctx.viewer, model.project_id)
    staging = count(v -> v.stage_id == Integer(STAGING), versions)
    archived = count(v -> v.stage_id == Integer(ARCHIVED), versions)

    crumbs = Any["Projects" => "/"]
    isnothing(project) || push!(crumbs, project.name => _project_url(project.id))
    push!(crumbs, model.name => nothing)

    production_badge = if isnothing(production)
        nothing
    else
        DOM.span(
            "v$(production.version) in production";
            class="dd-badge dd-badge--sage dd-badge--lg",
        )
    end
    editors = _model_editors(ctx, model, access)
    hero = _hero(;
        title=editors.title,
        lede=editors.lede,
        lede_empty="No description yet.",
        meta=_meta(
            _meta_item("Registered ", _format_datetime(model.created_date)),
            if isnothing(model.updated_date)
                nothing
            else
                _meta_item("Updated ", _format_datetime(model.updated_date))
            end,
            _id_chip(model.id),
        ),
        actions=Any[production_badge, editors.menu],
    )
    stats = _stats(
        _stat("Versions", length(versions)),
        _stat(
            "Production",
            isnothing(production) ? "–" : "v$(production.version)";
            mono=!isnothing(production),
        ),
        _stat("Staging", staging),
        _stat("Archived", archived);
    )
    body = if isempty(versions)
        _empty(
            "No versions registered.",
            "Version a checkpoint from the iteration that produced it:";
            snippet=_MODEL_SNIPPET,
        )
    else
        _versions_table(versions, ctx, access)
    end
    section = _section(
        "Versions",
        body;
        count=length(versions),
        note=(
            if isempty(versions)
                nothing
            else
                "Promoting a version to production archives the previous incumbent."
            end
        ),
    )
    return Page("$(model.name) · DearDiary", crumbs, Any[hero, _flash(ctx), stats, section])
end

function _versions_table(
    versions::AbstractVector{ModelVersion}, ctx::PageContext, access::Access
)
    editable = access.delete
    head = DOM.tr(
        _th("Version"; sort="num"),
        _th("Stage"; sort="text"),
        _th("Source iteration"),
        _th("Artifact"),
        _th("Description"),
        _th("Registered"; sort="num"),
        _th("Updated"; sort="num"),
        editable ? _th(DOM.span("Actions"; class="dd-sr-only")) : nothing,
    )
    rows = Any[]
    for version in versions
        push!(rows, _version_row(version, ctx, access))
    end
    return _table([head], rows; id="versions")
end

function _version_row(version::ModelVersion, ctx::PageContext, access::Access)
    iteration = get_iteration(version.iteration_id)
    source = if isnothing(iteration)
        DOM.span("Deleted iteration"; class="dd-dim")
    else
        experiment = get_experiment(iteration.experiment_id)
        DOM.span(
            _link(
                "Iteration $(_iteration_ordinal(iteration))",
                _iteration_url(iteration.id);
                class="dd-row-link",
            ),
            if isnothing(experiment)
                nothing
            else
                DOM.span(" · ", experiment.name; class="dd-dim")
            end,
        )
    end
    resource = isnothing(version.resource_id) ? nothing : get_resource(version.resource_id)
    artifact = if isnothing(resource)
        DOM.span("–"; class="dd-dim")
    else
        DOM.span(
            _link(resource.name, _download_url(resource.id)),
            DOM.span(" · $(_format_bytes(resource.size_bytes))"; class="dd-dim"),
        )
    end
    base = "/modelversion/$(version.id)"
    stage_cell = if access.update
        _td(
            _badge_select(
                ctx,
                base * "/edit",
                "stage",
                _STAGE_OPTIONS,
                string(version.stage_id),
                _stage(version.stage_id).tone;
                label="Stage of version $(version.version)",
            );
            value=_stage(version.stage_id).label,
        )
    else
        _td(_stage_badge(version.stage_id); value=_stage(version.stage_id).label)
    end
    description_cell = if access.update
        control = _text_input("description"; value=version.description, label="Description")
        editor = if isempty(version.description)
            trigger = DOM.button(
                "Add a description";
                type="button",
                class="dd-ghost-link",
                dataInlineOpen="#version-$(version.id)",
            )
            _inline_edit(
                ctx,
                "version-$(version.id)",
                base * "/edit",
                nothing,
                control;
                trigger=trigger,
            )
        else
            _inline_edit(
                ctx,
                "version-$(version.id)",
                base * "/edit",
                DOM.span(version.description),
                control;
                label="Edit description",
            )
        end
        _td(editor; class="dd-wrap")
    else
        _td(
            isempty(version.description) ? "–" : version.description;
            class=(isempty(version.description) ? "dd-dim" : "dd-wrap"),
        )
    end
    actions = if access.delete
        _td(
            _form(
                base * "/delete",
                ctx.csrf,
                DOM.button(
                    _trash_icon();
                    type="submit",
                    class="dd-ghost dd-ghost--danger",
                    ariaLabel="Delete version v$(version.version)",
                    title="Delete version",
                );
                confirm="Delete version v$(version.version)? The artifact is kept. This cannot be undone.",
                class="dd-menu-form",
            );
            class="dd-actions",
        )
    else
        nothing
    end
    return DOM.tr(
        _td("v$(version.version)"; class="dd-mono", value=version.version),
        stage_cell,
        _td(source),
        _td(artifact),
        description_cell,
        _time_cell(version.created_date),
        _time_cell(version.updated_date),
        actions,
    )
end
