# Hyperscript renders a `nothing` attribute as a bare boolean, so optional attributes are
# dropped before they reach the DOM constructors.
_attrs(; kwargs...) = [k => v for (k, v) in pairs(kwargs) if !isnothing(v)]

function _icon(paths::AbstractString...)
    return SVG.svg(
        (SVG.path(; d=d) for d in paths)...;
        viewBox="0 0 24 24",
        fill="none",
        stroke="currentColor",
        strokeWidth="2",
        strokeLinecap="round",
        strokeLinejoin="round",
        ariaHidden="true",
        class="dd-icon",
    )
end

_copy_icon() = _icon("M9 9h10v10H9z", "M5 15V5h10")
function _sun_icon()
    return _icon(
        "M12 4V2M12 22v-2M4 12H2M22 12h-2M5.6 5.6 4.2 4.2M19.8 19.8l-1.4-1.4M5.6 18.4l-1.4 1.4M19.8 4.2l-1.4 1.4",
        "M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10z",
    )
end
_moon_icon() = _icon("M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z")
_download_icon() = _icon("M12 4v11", "m7 10 5 5 5-5", "M4 19h16")

function _copy_button(text::AbstractString)
    return DOM.button(
        _copy_icon();
        type="button",
        class="dd-copy",
        dataCopy=text,
        ariaLabel="Copy to clipboard",
        title="Copy",
    )
end

function _badge(status; pulse::Bool=false, large::Bool=false, plain::Bool=false)
    class = "dd-badge dd-badge--$(status.tone)"
    pulse && (class *= " dd-badge--pulse")
    large && (class *= " dd-badge--lg")
    plain && (class *= " dd-badge--plain")
    return DOM.span(status.label; class=class)
end

function _iteration_badge(status_id::Integer; large::Bool=false)
    return _badge(
        _iteration_status(status_id); pulse=(status_id == Integer(RUNNING)), large=large
    )
end

function _experiment_badge(status_id::Integer; large::Bool=false)
    return _badge(_experiment_status(status_id); large=large)
end

_stage_badge(stage_id::Integer; large::Bool=false) = _badge(_stage(stage_id); large=large)

function _role_badge(user::User)
    return if user.is_admin
        _badge((tone="plum", label="admin"); plain=true)
    else
        _badge((tone="neutral", label="member"); plain=true)
    end
end

function _tag_chips(tags::AbstractVector{Tag})
    isempty(tags) && return nothing
    return DOM.div(
        (DOM.span(tag.value; class="dd-tag") for tag in tags)...; class="dd-tags"
    )
end

function _id_chip(id::AbstractString)
    return DOM.span(DOM.code(id), _copy_button(id); class="dd-id", title=id)
end

function _link(label, href::AbstractString; class::Optional{AbstractString}=nothing)
    return DOM.a(label; _attrs(; href=href, class=class)...)
end

function _external_link(label, href::AbstractString)
    return DOM.a(
        label; href=href, target="_blank", rel="noopener noreferrer", class="dd-arrow"
    )
end

function _stat(label::AbstractString, value; sub=nothing, mono::Bool=false)
    value_class = mono ? "dd-stat-value dd-stat-value--mono" : "dd-stat-value"
    return DOM.div(
        DOM.span(label; class="dd-stat-label"),
        DOM.span(string(value); class=value_class),
        isnothing(sub) ? nothing : DOM.span(sub; class="dd-stat-sub");
        class="dd-stat",
    )
end

_stats(items...) = DOM.div(items...; class="dd-stats")

_count_chip(n::Integer) = DOM.span(string(n); class="dd-count")

function _section(
    title::AbstractString,
    children...;
    count::Optional{Integer}=nothing,
    tools=nothing,
    note=nothing,
    id::Optional{AbstractString}=nothing,
)
    heading = DOM.h2(
        title, isnothing(count) ? nothing : _count_chip(count); class="dd-section-title"
    )
    head = DOM.div(heading, tools; class="dd-section-head")
    note_node = isnothing(note) ? nothing : DOM.p(note; class="dd-section-note")
    return DOM.section(head, note_node, children...; _attrs(; class="dd-section", id=id)...)
end

function _filter(table_id::AbstractString, placeholder::AbstractString)
    return DOM.div(
        DOM.span(; dataFilterCount="#$(table_id)"),
        DOM.input(;
            type="search",
            class="dd-filter",
            placeholder=placeholder,
            dataFilter="#$(table_id)",
            ariaLabel=placeholder,
            autocomplete="off",
        );
        class="dd-section-tools",
    )
end

function _empty(
    title::AbstractString, text::AbstractString; snippet::Optional{AbstractString}=nothing
)
    return DOM.div(
        DOM.p(title; class="dd-empty-title"),
        DOM.p(text),
        isnothing(snippet) ? nothing : _code(snippet);
        class="dd-empty",
    )
end

function _code(text::AbstractString; inline::Bool=false)
    class = inline ? "dd-code dd-code--inline" : "dd-code"
    # The block scrolls when long, so keyboard users must be able to focus it.
    return DOM.pre(text; class=class, tabindex="0")
end

function _fold(
    title::AbstractString, body; meta::Optional{AbstractString}=nothing, open::Bool=false
)
    summary = DOM.summary(
        title, isnothing(meta) ? nothing : DOM.span(meta; class="dd-fold-meta")
    )
    return DOM.details(
        summary,
        DOM.div(body; class="dd-fold-body");
        _attrs(; class="dd-fold", open=(open ? true : nothing))...,
    )
end

function _note(
    text::AbstractString; label::Optional{AbstractString}=nothing, error::Bool=false
)
    return DOM.div(
        isnothing(label) ? nothing : DOM.span(label; class="dd-note-label"),
        text;
        class=(error ? "dd-note dd-note--error" : "dd-note"),
    )
end

function _banner(kind::AbstractString, text::AbstractString)
    return DOM.div(text; class="dd-banner dd-banner--$(kind)", role="status")
end

function _meta_item(label::AbstractString, value...)
    return DOM.span(DOM.span(label; class="dd-meta-label"), value...)
end

function _meta(items...)
    nodes = [item for item in items if !isnothing(item)]
    isempty(nodes) && return nothing
    return DOM.div(nodes...; class="dd-meta")
end

"""
    _hero(; title, lede, lede_empty, meta, tags, actions)

Page header. `title` and `lede` accept either text or a DOM node, so a page can drop an
inline editor in place of the plain heading. `tags` sits under the metadata line and
`actions` (live pill, actions menu) in the top-right corner.
"""
function _hero(;
    title,
    lede=nothing,
    lede_empty::Optional{AbstractString}=nothing,
    meta=nothing,
    tags=nothing,
    actions=nothing,
)
    title_node = title isa AbstractString ? DOM.h1(title; class="dd-title") : title
    lede_node = if lede isa AbstractString
        if !isempty(lede)
            DOM.p(lede; class="dd-lede")
        elseif !isnothing(lede_empty)
            DOM.p(lede_empty; class="dd-lede dd-lede--empty")
        else
            nothing
        end
    else
        lede
    end
    main = DOM.div(title_node, lede_node, meta, tags; class="dd-hero-main")
    action_nodes = actions isa AbstractVector ? actions : Any[actions]
    action_nodes = [node for node in action_nodes if !isnothing(node)]
    side = isempty(action_nodes) ? nothing : DOM.div(action_nodes...; class="dd-hero-side")
    return DOM.header(main, side; class="dd-hero")
end

function _crumbs(items::AbstractVector)
    nodes = Any[]
    for (i, (label, href)) in enumerate(items)
        i > 1 && push!(nodes, DOM.span("/"; class="dd-crumb-sep"))
        if isnothing(href)
            push!(nodes, DOM.span(label; ariaCurrent="page"))
        else
            push!(nodes, DOM.a(label; href=href))
        end
    end
    return DOM.nav(nodes...; class="dd-crumbs", ariaLabel="Breadcrumb")
end

function _th(
    label;
    sort::Optional{AbstractString}=nothing,
    class::Optional{AbstractString}=nothing,
    col::Optional{Integer}=nothing,
    colspan::Optional{Integer}=nothing,
    rowspan::Optional{Integer}=nothing,
    title::Optional{AbstractString}=nothing,
)
    return DOM.th(
        label;
        _attrs(;
            scope="col",
            dataSort=sort,
            dataCol=(isnothing(col) ? nothing : string(col)),
            class=class,
            colspan=(isnothing(colspan) ? nothing : string(colspan)),
            rowspan=(isnothing(rowspan) ? nothing : string(rowspan)),
            title=title,
        )...,
    )
end

function _td(
    children...;
    class::Optional{AbstractString}=nothing,
    value=nothing,
    title::Optional{AbstractString}=nothing,
)
    return DOM.td(
        children...;
        _attrs(;
            class=class, dataValue=(isnothing(value) ? nothing : string(value)), title=title
        )...,
    )
end

function _table(
    head_rows::AbstractVector,
    body_rows::AbstractVector;
    id::Optional{AbstractString}=nothing,
    sortable::Bool=true,
    class::Optional{AbstractString}=nothing,
)
    table = DOM.table(
        DOM.thead(head_rows...),
        DOM.tbody(body_rows...);
        _attrs(;
            class=(isnothing(class) ? "dd-table" : "dd-table " * class),
            id=id,
            dataSortable=(sortable ? "true" : nothing),
        )...,
    )
    return DOM.div(table; class="dd-table-wrap")
end

function _kv(pairs::AbstractVector; sans::Bool=false)
    rows = [
        DOM.tr(
            DOM.th(label; scope="row"), DOM.td(value; class=(sans ? "dd-sans" : nothing))
        ) for (label, value) in pairs
    ]
    return DOM.table(DOM.tbody(rows...); class="dd-kv")
end

_card(children...) = DOM.div(DOM.div(children...; class="dd-card-body"); class="dd-card")

function _card_titled(
    title::AbstractString, children...; text::Optional{AbstractString}=nothing
)
    head = DOM.div(title, isnothing(text) ? nothing : DOM.p(text); class="dd-card-head")
    return DOM.div(head, DOM.div(children...; class="dd-card-body"); class="dd-card")
end

function _live_pill(seconds::Integer=15)
    return DOM.div(
        DOM.span("Refreshing in $(seconds) s"; dataLiveLabel="true"),
        DOM.button("Pause"; type="button");
        class="dd-live",
        dataLive=string(seconds),
    )
end

function _lineage_row(kind::AbstractString, name, time::AbstractString; current::Bool=false)
    return DOM.div(
        DOM.span(kind; class="dd-lineage-kind"),
        DOM.span(name; class="dd-lineage-name"),
        DOM.span(time; class="dd-lineage-time");
        class=(current ? "dd-lineage-row dd-lineage-row--current" : "dd-lineage-row"),
    )
end

# Stacked bar of iteration outcomes, widest segment first so a glance reads the dominant
# status. The tooltip carries the exact counts.
function _statusbar(counts::Dict{Int64,Int})
    total = sum(values(counts); init=0)
    total == 0 && return DOM.span("–"; class="dd-dim")
    segments = Any[]
    labels = String[]
    for status in (SUCCEEDED, FAILED, RUNNING, KILLED)
        n = get(counts, Integer(status), 0)
        n == 0 && continue
        chrome = _iteration_status(Integer(status))
        width = round(100 * n / total; digits=1)
        push!(
            segments, DOM.span(; class="dd-fill--$(chrome.tone)", style="width: $(width)%")
        )
        push!(labels, "$(n) $(chrome.label)")
    end
    summary = join(labels, " · ")
    return DOM.div(
        segments...; class="dd-statusbar", title=summary, role="img", ariaLabel=summary
    )
end

function _time_cell(dt::DateTime)
    return _td(
        _relative_time(dt);
        value=Dates.datetime2unix(dt),
        title=_format_datetime(dt),
        class="dd-nowrap",
    )
end
_time_cell(::Nothing) = _td("–"; class="dd-dim", value="")

function _duration_cell(d::Optional{Millisecond})
    isnothing(d) && return _td("–"; class="dd-dim", value="")
    return _td(_format_duration(d); value=d.value, class="dd-num")
end

function _description_line(text::AbstractString)
    isempty(text) && return nothing
    return DOM.div(_truncate(text, 90); class="dd-small dd-dim")
end

function _child_mark(parent_ordinal::Optional{Integer})
    isnothing(parent_ordinal) && return nothing
    return DOM.span(" child of #$(parent_ordinal)"; class="dd-child-mark")
end

function _parameter_cell(value::Optional{AbstractString}, prefix::AbstractString)
    isnothing(value) && return _td("–"; class=prefix * "dd-dim", value="")
    return _td(
        _truncate(value, 40); class=prefix * "dd-mono dd-clip", value=value, title=value
    )
end

function _metric_cell(value::Optional{Float64}, prefix::AbstractString)
    isnothing(value) && return _td("–"; class=prefix * "dd-dim dd-num", value="")
    return _td(
        _format_number(value);
        class=prefix * "dd-num",
        value=(isfinite(value) ? value : ""),
        title=string(value),
    )
end

function _notes_cell(notes::AbstractString)
    isempty(notes) && return _td("–"; class="dd-dim", value="")
    return _td(_truncate(notes, 80); class="dd-clip", title=notes, value=notes)
end

# ---------- forms ----------

function _field(label::AbstractString, control; hint::Optional{AbstractString}=nothing)
    return DOM.label(
        DOM.span(label; class="dd-label"),
        control,
        isnothing(hint) ? nothing : DOM.span(hint; class="dd-hint");
        class="dd-field",
    )
end

function _text_input(
    name::AbstractString;
    value::AbstractString="",
    type::AbstractString="text",
    placeholder::Optional{AbstractString}=nothing,
    required::Bool=false,
    autocomplete::Optional{AbstractString}=nothing,
    mono::Bool=false,
    readonly::Bool=false,
    large::Bool=false,
    label::Optional{AbstractString}=nothing,
)
    class = "dd-input"
    mono && (class *= " dd-input--mono")
    large && (class *= " dd-input--title")
    return DOM.input(;
        _attrs(;
            type=type,
            name=name,
            value=value,
            class=class,
            ariaLabel=label,
            placeholder=placeholder,
            required=(required ? "required" : nothing),
            autocomplete=autocomplete,
            readonly=(readonly ? "readonly" : nothing),
        )...,
    )
end

function _checkbox(
    name::AbstractString,
    label;
    checked::Bool=false,
    disabled::Bool=false,
    value::AbstractString="on",
)
    return DOM.label(
        DOM.input(;
            _attrs(;
                type="checkbox",
                name=name,
                value=value,
                checked=(checked ? "checked" : nothing),
                disabled=(disabled ? "disabled" : nothing),
            )...,
        ),
        label;
        class="dd-check",
    )
end

function _hidden(name::AbstractString, value::AbstractString)
    return DOM.input(; type="hidden", name=name, value=value)
end

function _button(
    label;
    kind::AbstractString="",
    type::AbstractString="submit",
    disabled::Bool=false,
    small::Bool=false,
)
    class = "dd-btn"
    isempty(kind) || (class *= " dd-btn--$(kind)")
    small && (class *= " dd-btn--sm")
    return DOM.button(
        label;
        _attrs(; type=type, class=class, disabled=(disabled ? "disabled" : nothing))...,
    )
end

"""
    _form(action, csrf, children...; confirm=nothing)

A same-origin POST form carrying the session's CSRF token. `confirm` asks the browser for
confirmation before submitting, for destructive actions.
"""
function _form(
    action::AbstractString,
    csrf::AbstractString,
    children...;
    confirm::Optional{AbstractString}=nothing,
    class::AbstractString="dd-form",
)
    return DOM.form(
        _hidden(_CSRF_FIELD, csrf),
        children...;
        _attrs(; method="post", action=action, class=class, dataConfirm=confirm)...,
    )
end

function _textarea(
    name::AbstractString;
    value::AbstractString="",
    rows::Integer=3,
    placeholder::Optional{AbstractString}=nothing,
    label::Optional{AbstractString}=nothing,
)
    return DOM.textarea(
        value;
        _attrs(;
            name=name,
            class="dd-input dd-textarea",
            rows=string(rows),
            placeholder=placeholder,
            ariaLabel=label,
        )...,
    )
end

function _select(name::AbstractString, options::AbstractVector; value::AbstractString="")
    return DOM.select(
        (
            DOM.option(
                label;
                _attrs(; value=key, selected=(key == value ? "selected" : nothing))...,
            ) for (key, label) in options
        )...;
        name=name,
        class="dd-input dd-select",
    )
end

_pencil_icon() = _icon("M4 20h4l10.5-10.5a2.1 2.1 0 0 0-3-3L5 17v3z", "m13.5 6.5 3 3")
_more_icon() = _icon("M5 12h.01", "M12 12h.01", "M19 12h.01")
_trash_icon() = _icon("M4 7h16", "M10 11v6", "M14 11v6", "M6 7l1 13h10l1-13", "M9 7V4h6v3")

"""
    _tip(node, text)

Wrap `node` so a short explanation appears on hover or focus. Used for controls that are
present but unavailable right now, so the reason is one hover away instead of hidden.
"""
_tip(node, text::AbstractString) =
    DOM.span(node, DOM.span(" " * text; class="dd-sr-only"); class="dd-tip", dataTip=text)

"""
    _inline_edit(ctx, id, action, view, control; label, trigger)

Click-to-edit control: `view` shows the current value next to a pencil button; the button
swaps it for a small form posting `control` to `action`. `trigger` replaces the pencil with
a custom opener, for empty states such as "Add a description".
"""
function _inline_edit(
    ctx::PageContext,
    id::AbstractString,
    action::AbstractString,
    view,
    control;
    label::AbstractString="Edit",
    trigger=nothing,
)
    opener = if isnothing(trigger)
        DOM.button(
            _pencil_icon();
            type="button",
            class="dd-ghost",
            dataInlineOpen="#$(id)",
            ariaLabel=label,
            title=label,
        )
    else
        trigger
    end
    form = DOM.form(
        _hidden(_CSRF_FIELD, ctx.csrf),
        control,
        DOM.div(
            _button("Save"; kind="primary", small=true),
            DOM.button(
                "Cancel"; type="button", class="dd-btn dd-btn--sm", dataInlineCancel="true"
            );
            class="dd-inline-actions",
        );
        method="post",
        action=action,
        class="dd-inline-form",
        hidden="hidden",
        dataInline="true",
    )
    return DOM.div(
        DOM.div(view, opener; class="dd-inline-view", dataInlineView="true"),
        form;
        class="dd-inline",
        id=id,
    )
end

"""
    _menu(items...)

The page's actions menu: a `details` element that drops a list of actions from a "more"
button. Returns `nothing` when there is nothing to offer, so read-only viewers see no menu.
"""
function _menu(items...)
    nodes = [item for item in items if !isnothing(item)]
    isempty(nodes) && return nothing
    return DOM.details(
        DOM.summary(
            _more_icon();
            class="dd-btn dd-btn--sm dd-btn--icon",
            ariaLabel="More actions",
            title="More actions",
        ),
        DOM.div(nodes...; class="dd-menu-list");
        class="dd-menu",
    )
end

"""
    _menu_action(ctx, label, action; confirm, danger, hint, disabled)

One entry of the actions menu. `disabled` is the reason the action is unavailable right
now; the entry then stays visible but inert, with the reason in a tooltip, following the
rule that a control which may become available is disabled while one the viewer may never
use is hidden.
"""
function _menu_action(
    ctx::PageContext,
    label::AbstractString,
    action::AbstractString;
    confirm::Optional{AbstractString}=nothing,
    danger::Bool=false,
    hint::Optional{AbstractString}=nothing,
    disabled::Optional{AbstractString}=nothing,
)
    class = danger ? "dd-menu-item dd-menu-item--danger" : "dd-menu-item"
    content = (
        DOM.span(label), isnothing(hint) ? nothing : DOM.span(hint; class="dd-menu-hint")
    )
    if !isnothing(disabled)
        button = DOM.button(
            content...; type="button", class=class * " is-disabled", ariaDisabled="true"
        )
        return _tip(button, disabled)
    end
    button = DOM.button(content...; type="submit", class=class)
    return _form(action, ctx.csrf, button; confirm=confirm, class="dd-menu-form")
end

"""
    _badge_select(ctx, action, name, options, value, tone; label)

A lifecycle control styled like the status badge it replaces. Changing it submits at once.
"""
function _badge_select(
    ctx::PageContext,
    action::AbstractString,
    name::AbstractString,
    options::AbstractVector,
    value::AbstractString,
    tone::AbstractString;
    label::AbstractString,
)
    select = DOM.select(
        (
            DOM.option(
                text; _attrs(; value=key, selected=(key == value ? "selected" : nothing))...
            ) for (key, text) in options
        )...;
        name=name,
        class="dd-badge-select dd-badge--$(tone)",
        dataAutosubmit="true",
        ariaLabel=label,
        title=label,
    )
    return DOM.form(
        _hidden(_CSRF_FIELD, ctx.csrf),
        select,
        DOM.button("Apply"; type="submit", class="dd-sr-only", dataApply="true");
        method="post",
        action=action,
        class="dd-badge-form",
    )
end

"""
    _tag_row(tags, adder)

The tag chips with an optional "+ Tag" opener at the end.
"""
function _tag_row(tags::AbstractVector{Tag}, adder)
    chips = Any[DOM.span(tag.value; class="dd-tag") for tag in tags]
    isempty(chips) && isnothing(adder) && return nothing
    return DOM.div(chips..., adder; class="dd-tags dd-tags-row")
end

function _tag_adder(ctx::PageContext, action::AbstractString)
    opener = DOM.button(
        "+ Tag";
        type="button",
        class="dd-tag dd-tag--add",
        dataInlineOpen="#tag-add",
        title="Add a tag",
    )
    control = DOM.input(;
        type="text",
        name="tag",
        class="dd-input dd-input--tag",
        placeholder="tag",
        required="required",
        ariaLabel="New tag",
        autocomplete="off",
    )
    form = DOM.form(
        _hidden(_CSRF_FIELD, ctx.csrf),
        control,
        _button("Add"; kind="primary", small=true),
        DOM.button(
            "Cancel"; type="button", class="dd-btn dd-btn--sm", dataInlineCancel="true"
        );
        method="post",
        action=action,
        class="dd-inline-form dd-inline-form--row",
        hidden="hidden",
        dataInline="true",
    )
    return DOM.span(
        DOM.span(opener; dataInlineView="true"),
        form;
        class="dd-inline dd-tag-adder",
        id="tag-add",
    )
end
