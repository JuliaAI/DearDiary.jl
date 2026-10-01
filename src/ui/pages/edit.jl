# Editing tracking records from the dashboard. Only the fields the service layer lets a
# client change are exposed: names, descriptions, lifecycle status and stage, notes while
# an iteration is still running, and tags. Parameters, metrics, artifacts, and environment
# snapshots are the evidence a run leaves behind and stay read-only.

const _ENTITY_POST_PATTERN = r"^/(project|experiment|iteration|model|modelversion)/([^/?#]+)/(edit|tags|kill|delete)/?$"

function _can(
    viewer::User, project_id::Optional{AbstractString}, ::Type{A}
)::Bool where {A<:PermissionAction}
    isnothing(project_id) && return false
    viewer.is_admin && return true
    permission = get_userpermission(viewer.id, project_id)
    return !isnothing(permission) && has_permission(permission, A)
end

function _access(viewer::User, project_id::Optional{AbstractString})::Access
    return Access(
        _can(viewer, project_id, UpdatePermission),
        _can(viewer, project_id, CreatePermission),
        _can(viewer, project_id, DeletePermission),
    )
end

_any(access::Access)::Bool = access.update || access.create || access.delete

# ---------- notices ----------

const _FLASH_MESSAGES = Dict{String,Tuple{String,String}}(
    "saved" => ("ok", "Changes saved."),
    "tag" => ("ok", "Tag added."),
    "killed" => ("ok", "Iteration marked as killed."),
    "deleted" => ("ok", "Deleted."),
    "created" => ("ok", "User created."),
    "profile" => ("ok", "Profile saved."),
    "password" => ("ok", "Password changed."),
    "role" => ("ok", "Role saved."),
    "permissions" => ("ok", "Project access saved."),
    "csrf" => ("err", "The form expired. Reload the page and try again."),
    "invalid" => ("err", "The server rejected the change. Check the values and try again."),
    "duplicate" => ("err", "That name is already in use."),
    "name" => ("err", "A name is required."),
    "tag_empty" => ("err", "Enter a tag."),
    "tag_exists" => ("err", "That tag is already attached."),
    "registered" => (
        "err",
        "Model versions are registered from this record. Delete those versions first.",
    ),
    "locked" =>
        ("err", "This iteration has ended, so its notes and tags can no longer change."),
    "username" => ("err", "A username is required."),
    "password_empty" => ("err", "The password cannot be empty."),
    "password_mismatch" => ("err", "The two passwords do not match."),
    "self" => ("err", "You cannot change your own role or delete your own account."),
    "default_user" => ("err", "The seeded default account cannot be deleted or demoted."),
    "forbidden" => ("err", "You are not allowed to do that."),
)

function _flash(ctx::PageContext)
    for key in ("ok", "err")
        code = get(ctx.query, key, nothing)
        isnothing(code) && continue
        entry = get(_FLASH_MESSAGES, code, nothing)
        isnothing(entry) && continue
        return _banner(entry[1], entry[2])
    end
    return nothing
end

_with_flash(path::AbstractString, kind::AbstractString, code::AbstractString)::String =
    "$(path)?$(kind)=$(code)"

# ---------- editors ----------

const _EXPERIMENT_STATUS_OPTIONS = [
    (string(Integer(IN_PROGRESS)), "In progress"),
    (string(Integer(STOPPED)), "Stopped"),
    (string(Integer(FINISHED)), "Finished"),
]

const _STAGE_OPTIONS = [
    (string(Integer(NO_STAGE)), "No stage"),
    (string(Integer(STAGING)), "Staging"),
    (string(Integer(PRODUCTION)), "Production"),
    (string(Integer(ARCHIVED)), "Archived"),
]

# "Registered as v1 of iris-forest, v3 of iris-logreg": the versions that keep a record alive.
function _registered_text(versions::AbstractVector{ModelVersion})::String
    labels = String[]
    for version in versions
        model = get_model(version.model_id)
        push!(
            labels,
            "v$(version.version) of $(isnothing(model) ? "a deleted model" : model.name)",
        )
    end
    return "Registered as $(join(labels, ", ")). Delete those versions first."
end

function _title_editor(
    ctx::PageContext, action::AbstractString, name::AbstractString; label::AbstractString
)
    control = _text_input("name"; value=name, required=true, large=true, label="Name")
    return _inline_edit(
        ctx, "edit-name", action, DOM.h1(name; class="dd-title"), control; label=label
    )
end

function _description_editor(ctx::PageContext, action::AbstractString, text::AbstractString)
    control = _textarea(
        "description"; value=text, placeholder="Describe this record", label="Description"
    )
    if isempty(text)
        trigger = DOM.button(
            "Add a description";
            type="button",
            class="dd-ghost-link",
            dataInlineOpen="#edit-description",
        )
        return _inline_edit(
            ctx, "edit-description", action, nothing, control; trigger=trigger
        )
    end
    return _inline_edit(
        ctx,
        "edit-description",
        action,
        DOM.p(text; class="dd-lede"),
        control;
        label="Edit description",
    )
end

function _notes_editor(ctx::PageContext, action::AbstractString, notes::AbstractString)
    control = _textarea(
        "notes";
        value=notes,
        rows=4,
        placeholder="Notes about this iteration",
        label="Notes",
    )
    if isempty(notes)
        trigger = DOM.button(
            "Add notes"; type="button", class="dd-ghost-link", dataInlineOpen="#edit-notes"
        )
        return _inline_edit(ctx, "edit-notes", action, nothing, control; trigger=trigger)
    end
    return _inline_edit(
        ctx, "edit-notes", action, _note(notes; label="Notes"), control; label="Edit notes"
    )
end

function _delete_action(
    ctx::PageContext,
    base::AbstractString,
    label::AbstractString,
    confirm::AbstractString,
    hint::AbstractString;
    blocked_by::AbstractVector{ModelVersion}=ModelVersion[],
)
    disabled = isempty(blocked_by) ? nothing : _registered_text(blocked_by)
    return _menu_action(
        ctx,
        label,
        base * "/delete";
        confirm=confirm,
        danger=true,
        hint=hint,
        disabled=disabled,
    )
end

"""
    _project_editors(ctx, project, tags)

The hero pieces of a project page: inline name and description editors and the actions
menu for administrators, and a tag opener for anyone with create permission.
"""
function _project_editors(ctx::PageContext, project::Project, tags::AbstractVector{Tag})
    admin = ctx.viewer.is_admin
    base = _project_url(project.id)
    title = if admin
        _title_editor(ctx, base * "/edit", project.name; label="Rename project")
    else
        project.name
    end
    lede = if admin
        _description_editor(ctx, base * "/edit", project.description)
    else
        project.description
    end
    adder = if _can(ctx.viewer, project.id, CreatePermission)
        _tag_adder(ctx, base * "/tags")
    else
        nothing
    end
    menu = if admin
        _menu(
            _delete_action(
                ctx,
                base,
                "Delete project",
                "Delete $(project.name) with every experiment, iteration, artifact, and registry entry in it? This cannot be undone.",
                "Removes everything recorded under the project.",
            ),
        )
    else
        nothing
    end
    return (title=title, lede=lede, tags=_tag_row(tags, adder), menu=menu)
end

function _experiment_editors(
    ctx::PageContext, experiment::Experiment, access::Access, tags::AbstractVector{Tag}
)
    base = _experiment_url(experiment.id)
    title = if access.update
        _title_editor(ctx, base * "/edit", experiment.name; label="Rename experiment")
    else
        experiment.name
    end
    lede = if access.update
        _description_editor(ctx, base * "/edit", experiment.description)
    else
        experiment.description
    end
    status = if access.update
        _badge_select(
            ctx,
            base * "/edit",
            "status",
            _EXPERIMENT_STATUS_OPTIONS,
            string(experiment.status_id),
            _experiment_status(experiment.status_id).tone;
            label="Experiment status",
        )
    else
        _experiment_badge(experiment.status_id)
    end
    adder = access.create ? _tag_adder(ctx, base * "/tags") : nothing
    menu = if access.delete
        _menu(
            _delete_action(
                ctx,
                base,
                "Delete experiment",
                "Delete $(experiment.name) with all of its iterations and artifacts? This cannot be undone.",
                "Removes its iterations and artifacts.";
                blocked_by=get_modelversions(Experiment, experiment.id),
            ),
        )
    else
        nothing
    end
    return (title=title, lede=lede, status=status, tags=_tag_row(tags, adder), menu=menu)
end

function _iteration_editors(
    ctx::PageContext,
    iteration::Iteration,
    ordinal::Integer,
    access::Access,
    tags::AbstractVector{Tag},
)
    base = _iteration_url(iteration.id)
    running = isnothing(iteration.end_date)
    notes = if running && access.update
        _notes_editor(ctx, base * "/edit", iteration.notes)
    elseif !isempty(iteration.notes)
        _note(iteration.notes; label="Notes")
    else
        nothing
    end
    adder = running && access.create ? _tag_adder(ctx, base * "/tags") : nothing
    lock = if !running && (access.update || access.create)
        _tip(
            DOM.span("locked"; class="dd-badge dd-badge--plain"),
            "Ended iterations are read-only: notes and tags are fixed, like parameters and metrics.",
        )
    else
        nothing
    end
    kill = if access.update
        _menu_action(
            ctx,
            "Mark as killed",
            base * "/kill";
            confirm="Mark Iteration $(ordinal) as killed? It can no longer receive metrics afterwards.",
            danger=true,
            hint="Ends it now with the killed status.",
            disabled=(running ? nothing : "Only running iterations can be killed."),
        )
    else
        nothing
    end
    delete = if access.delete
        _delete_action(
            ctx,
            base,
            "Delete iteration",
            "Delete Iteration $(ordinal) with its parameters and metrics? Child iterations are kept and detached. This cannot be undone.",
            "Removes its parameters and metrics.";
            blocked_by=get_modelversions(Iteration, iteration.id),
        )
    else
        nothing
    end
    return (notes=notes, tags=_tag_row(tags, adder), lock=lock, menu=_menu(kill, delete))
end

function _model_editors(ctx::PageContext, model::Model, access::Access)
    base = _model_url(model.id)
    title = if access.update
        _title_editor(ctx, base * "/edit", model.name; label="Rename model")
    else
        model.name
    end
    lede = if access.update
        _description_editor(ctx, base * "/edit", model.description)
    else
        model.description
    end
    menu = if access.delete
        _menu(
            _delete_action(
                ctx,
                base,
                "Delete model",
                "Delete $(model.name) and all of its versions from the registry? Artifacts are kept. This cannot be undone.",
                "Removes the registry entry and its versions; artifacts stay.",
            ),
        )
    else
        nothing
    end
    return (title=title, lede=lede, menu=menu)
end

# ---------- form handling ----------

function _entity_for_post(kind::AbstractString, id::AbstractString)
    if kind == "project"
        project = get_project(id)
        isnothing(project) && return nothing
        return (
            entity=project, project_id=project.id, back=_project_url(project.id), parent="/"
        )
    elseif kind == "experiment"
        experiment = get_experiment(id)
        isnothing(experiment) && return nothing
        return (
            entity=experiment,
            project_id=experiment.project_id,
            back=_experiment_url(experiment.id),
            parent=_project_url(experiment.project_id),
        )
    elseif kind == "iteration"
        iteration = get_iteration(id)
        isnothing(iteration) && return nothing
        return (
            entity=iteration,
            project_id=get_project_id(iteration),
            back=_iteration_url(iteration.id),
            parent=_experiment_url(iteration.experiment_id),
        )
    elseif kind == "model"
        model = get_model(id)
        isnothing(model) && return nothing
        return (
            entity=model,
            project_id=model.project_id,
            back=_model_url(model.id),
            parent=_project_url(model.project_id),
        )
    else
        version = get_modelversion(id)
        isnothing(version) && return nothing
        model = get_model(version.model_id)
        isnothing(model) && return nothing
        return (
            entity=version,
            project_id=model.project_id,
            back=_model_url(model.id),
            parent=_model_url(model.id),
        )
    end
end

function _result_code(result)::String
    result === Updated && return "saved"
    result === Duplicate && return "duplicate"
    return "invalid"
end

"""
    _handle_entity_post(ctx::PageContext, request::HTTP.Request)::HTTP.Response

Apply an edit, tag, kill, or delete form to a tracking record, with the same permission
checks as the REST routes: project changes need an administrator, edits need update
permission, tags need create permission, and deletes need delete permission.
"""
function _handle_entity_post(ctx::PageContext, request::HTTP.Request)::HTTP.Response
    m = match(_ENTITY_POST_PATTERN, ctx.path)
    isnothing(m) && return HTTP.Response(404, "Not found")
    kind, id, action = String(m[1]), String(m[2]), String(m[3])
    target = _entity_for_post(kind, id)
    isnothing(target) && return HTTP.Response(404, "Not found")
    viewer = ctx.viewer
    _can(viewer, target.project_id, ReadPermission) ||
        return HTTP.Response(404, "Not found")
    fields = _form_fields(request)
    back = target.back
    _post_allowed(request, fields) || return _redirect(_with_flash(back, "err", "csrf"))

    access = if kind == "project"
        Access(viewer.is_admin, viewer.is_admin, viewer.is_admin)
    else
        _access(viewer, target.project_id)
    end
    needed = if action == "tags"
        access.create
    elseif action == "delete"
        access.delete
    else
        access.update
    end
    needed || return _redirect(_with_flash(back, "err", "forbidden"))

    if action == "delete"
        deleted = _delete_entity(kind, id)
        deleted && return _redirect(_with_flash(target.parent, "ok", "deleted"))
        return _redirect(_with_flash(back, "err", _delete_failure(kind, id)))
    elseif action == "tags"
        return _redirect(_with_flash(back, _add_tag_from_form(kind, id, fields)...))
    elseif action == "kill"
        kind == "iteration" || return HTTP.Response(404, "Not found")
        result = update_iteration(id, nothing, now(), KILLED)
        return _redirect(
            if result === Updated
                _with_flash(back, "ok", "killed")
            else
                _with_flash(back, "err", "locked")
            end,
        )
    end
    return _redirect(_with_flash(back, _edit_from_form(kind, target.entity, fields)...))
end

function _delete_entity(kind::AbstractString, id::AbstractString)::Bool
    kind == "project" && return delete_project(id)
    kind == "experiment" && return delete_experiment(id)
    kind == "iteration" && return delete_iteration(id)
    kind == "model" && return delete_model(id)
    return delete_modelversion(id)
end

function _add_tag_from_form(
    kind::AbstractString, id::AbstractString, fields::AbstractDict
)::Tuple{String,String}
    value = strip(get(fields, "tag", ""))
    isempty(value) && return ("err", "tag_empty")
    type = if kind == "project"
        Project
    elseif kind == "experiment"
        Experiment
    elseif kind == "iteration"
        Iteration
    else
        nothing
    end
    isnothing(type) && return ("err", "invalid")
    _, status = add_tag(type, id, value)
    status === Created && return ("ok", "tag")
    status === Duplicate && return ("err", "tag_exists")
    kind == "iteration" && return ("err", "locked")
    return ("err", "invalid")
end

# Only changed fields reach the service layer, and a form may carry a single field: the
# store refuses to touch an indexed column such as a model name while versions reference
# the row, even with the same value, and the inline editors post one field at a time.
_changed(new::AbstractString, old::AbstractString) = new == old ? nothing : String(new)
_changed(::Nothing, ::AbstractString) = nothing

function _parsed_option(fields::AbstractDict, key::AbstractString, valid)
    haskey(fields, key) || return (present=false, value=nothing)
    value = tryparse(Int, fields[key])
    (isnothing(value) || !(value in valid)) && return (present=true, value=nothing)
    return (present=true, value=value)
end

function _edit_from_form(
    kind::AbstractString, entity, fields::AbstractDict
)::Tuple{String,String}
    name = haskey(fields, "name") ? String(strip(fields["name"])) : nothing
    description = get(fields, "description", nothing)
    (!isnothing(name) && isempty(name)) && return ("err", "name")
    if kind == "project"
        result = update_project(
            entity.id,
            _changed(name, entity.name),
            _changed(description, entity.description),
        )
    elseif kind == "experiment"
        status = _parsed_option(fields, "status", Int.(instances(ExperimentStatus)))
        (status.present && isnothing(status.value)) && return ("err", "invalid")
        status_id = status.present ? status.value : entity.status_id
        end_date =
            status_id == Integer(IN_PROGRESS) ? nothing : something(entity.end_date, now())
        result = update_experiment(
            entity.id,
            status_id,
            _changed(name, entity.name),
            _changed(description, entity.description),
            end_date,
        )
    elseif kind == "iteration"
        result = update_iteration(
            entity.id, _changed(get(fields, "notes", nothing), entity.notes), nothing
        )
        result === Unprocessable && return ("err", "locked")
    elseif kind == "model"
        result = update_model(
            entity.id,
            _changed(name, entity.name),
            _changed(description, entity.description),
        )
    else
        stage = _parsed_option(fields, "stage", Int.(instances(Stage)))
        (stage.present && isnothing(stage.value)) && return ("err", "invalid")
        result = update_modelversion(
            entity.id, stage.value, _changed(description, entity.description), nothing
        )
    end
    return (result === Updated ? "ok" : "err", _result_code(result))
end

function _delete_failure(kind::AbstractString, id::AbstractString)::String
    registered = if kind == "iteration"
        get_modelversions(Iteration, id)
    elseif kind == "experiment"
        get_modelversions(Experiment, id)
    else
        ModelVersion[]
    end
    return isempty(registered) ? "invalid" : "registered"
end
