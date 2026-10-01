const _USER_PATTERN = r"^/users/([^/?#]+)(?:/(profile|password|role|permissions|delete))?/?$"

_users_url()::String = "/users"
_user_url(id::AbstractString)::String = "/users/$(id)"

"""
    _render_users(ctx::PageContext)::Page

Every account with its role and project access, plus the form to add one. Admins only.
"""
function _render_users(ctx::PageContext)::Page
    users = sort(get_users(); by=u -> u.username)
    projects = get_projects()
    rows = Any[]
    for user in users
        access = if user.is_admin
            DOM.span("all projects"; class="dd-dim")
        else
            n = count(p -> p.read_permission, get_userpermissions(User, user.id))
            "$(n) of $(length(projects))"
        end
        push!(
            rows,
            DOM.tr(
                _td(_link(_display_name(user), _user_url(user.id); class="dd-row-link")),
                _td(user.username; class="dd-mono", value=user.username),
                _td(_role_badge(user); value=(user.is_admin ? "admin" : "member")),
                _td(access),
                _time_cell(user.created_date),
                _td(
                    _link("Edit", _user_url(user.id); class="dd-btn dd-btn--sm");
                    class="dd-actions",
                ),
            ),
        )
    end
    head = DOM.tr(
        _th("Name"; sort="text"),
        _th("Username"; sort="text"),
        _th("Role"; sort="text"),
        _th("Project access"),
        _th("Created"; sort="num"),
        _th(DOM.span("Actions"; class="dd-sr-only")),
    )
    table = _table([head], rows; id="users")
    form = _form(
        _users_url(),
        ctx.csrf,
        DOM.div(
            _field("First name", _text_input("first_name"; autocomplete="off")),
            _field("Last name", _text_input("last_name"; autocomplete="off"));
            class="dd-form-row",
        ),
        DOM.div(
            _field(
                "Username",
                _text_input("username"; required=true, mono=true, autocomplete="off"),
            ),
            _field(
                "Password",
                _text_input(
                    "password"; type="password", required=true, autocomplete="new-password"
                ),
            );
            class="dd-form-row",
        ),
        _checkbox("is_admin", "Administrator: can manage users and read every project"),
        DOM.div(_button("Create user"; kind="primary"); class="dd-form-actions"),
    )
    hero = _hero(;
        title="Users",
        lede="Accounts that can sign in to this DearDiary server. Administrators see every project; members see the projects they were granted.",
    )
    body = Any[
        hero,
        _flash(ctx),
        _section(
            "Accounts", table; count=length(users), tools=_filter("users", "Filter users")
        ),
        _section("Add a user", _card(form)),
    ]
    return Page("Users · DearDiary", Any["Projects" => "/", "Users" => nothing], body)
end

"""
    _render_user(ctx::PageContext, user::User)::Page

Profile, password, role, and project access for one account. The viewer edits their own
account here (`/settings`); admins reach any account from the users list.
"""
function _render_user(ctx::PageContext, user::User)::Page
    viewer = ctx.viewer
    is_self = viewer.id == user.id
    admin = viewer.is_admin
    is_default = user.username == "default"
    base = _user_url(user.id)

    crumbs = Any["Projects" => "/"]
    admin && push!(crumbs, "Users" => _users_url())
    push!(crumbs, (is_self ? "Settings" : _display_name(user)) => nothing)

    hero = _hero(;
        title=(is_self ? "Your account" : _display_name(user)),
        meta=_meta(
            _role_badge(user),
            _meta_item("Username ", DOM.code(user.username)),
            _meta_item("Created ", _format_date(user.created_date)),
            _id_chip(user.id),
        ),
    )

    profile = _form(
        base * "/profile",
        ctx.csrf,
        DOM.div(
            _field("First name", _text_input("first_name"; value=user.first_name)),
            _field("Last name", _text_input("last_name"; value=user.last_name));
            class="dd-form-row",
        ),
        _field(
            "Username",
            _text_input("username"; value=user.username, mono=true, readonly=true);
            hint="Usernames cannot be changed.",
        ),
        DOM.div(_button("Save profile"; kind="primary"); class="dd-form-actions"),
    )
    password = _form(
        base * "/password",
        ctx.csrf,
        DOM.div(
            _field(
                "New password",
                _text_input(
                    "password"; type="password", required=true, autocomplete="new-password"
                ),
            ),
            _field(
                "Repeat it",
                _text_input(
                    "password_confirm";
                    type="password",
                    required=true,
                    autocomplete="new-password",
                ),
            );
            class="dd-form-row",
        ),
        DOM.div(_button("Change password"; kind="primary"); class="dd-form-actions"),
    )
    sections = Any[
        hero,
        _flash(ctx),
        _section("Profile", _card(profile)),
        _section("Password", _card(password)),
    ]
    if admin
        role_hint = if is_default
            "The seeded default account always stays an administrator."
        elseif is_self
            "You cannot change your own role; ask another administrator."
        else
            "Administrators manage users and read every project."
        end
        role = _form(
            base * "/role",
            ctx.csrf,
            _checkbox(
                "is_admin",
                "Administrator";
                checked=user.is_admin,
                disabled=(is_self || is_default),
            ),
            DOM.div(
                _button("Save role"; kind="primary", disabled=(is_self || is_default)),
                DOM.span(role_hint; class="dd-hint");
                class="dd-form-actions",
            ),
        )
        push!(sections, _section("Role", _card(role)))
        push!(sections, _section("Project access", _permissions_block(ctx, user)))
        if !is_self && !is_default
            danger = _form(
                base * "/delete",
                ctx.csrf,
                DOM.div(
                    _button("Delete this user"; kind="danger"),
                    DOM.span(
                        "Removes the account and its project permissions. Projects, experiments, and iterations are kept.";
                        class="dd-hint",
                    );
                    class="dd-form-actions",
                );
                confirm="Delete $(_display_name(user))? This cannot be undone.",
            )
            push!(sections, _section("Remove account", _card(danger)))
        end
    end
    title = is_self ? "Settings · DearDiary" : "$(_display_name(user)) · DearDiary"
    return Page(title, crumbs, sections)
end

function _permissions_block(ctx::PageContext, user::User)
    if user.is_admin
        return _empty(
            "Administrators can read, create, update, and delete in every project.",
            "Change the role above to grant project-level access instead.",
        )
    end
    projects = sort(get_projects(); by=p -> p.name)
    isempty(projects) && return _empty(
        "No projects yet.", "Permissions are granted per project once one exists."
    )
    existing = Dict(p.project_id => p for p in get_userpermissions(User, user.id))
    head = DOM.tr(
        _th("Project"),
        _th("Read"; class="dd-check-head"),
        _th("Create"; class="dd-check-head"),
        _th("Update"; class="dd-check-head"),
        _th("Delete"; class="dd-check-head"),
    )
    rows = Any[]
    for project in projects
        permission = get(existing, project.id, nothing)
        flags = _permission_flags(permission)
        cells = Any[_td(_link(project.name, _project_url(project.id); class="dd-row-link"))]
        for (action, checked) in zip(("read", "create", "update", "delete"), flags)
            push!(
                cells,
                DOM.td(
                    DOM.input(;
                        _attrs(;
                            type="checkbox",
                            name="perm:$(project.id):$(action)",
                            value="on",
                            checked=(checked ? "checked" : nothing),
                            ariaLabel="$(action) $(project.name)",
                        )...,
                    );
                    class="dd-check-cell",
                ),
            )
        end
        push!(rows, DOM.tr(cells...))
    end
    form = _form(
        _user_url(user.id) * "/permissions",
        ctx.csrf,
        _table([head], rows; sortable=false, class="dd-matrix"),
        DOM.div(
            _button("Save access"; kind="primary"),
            DOM.span(
                "Projects with no box checked are hidden from this user."; class="dd-hint"
            );
            class="dd-form-actions",
        ),
    )
    return form
end

"""
    _handle_users_post(ctx::PageContext, request::HTTP.Request)::HTTP.Response

Apply a user-management form. Authorization mirrors the REST routes: anyone may edit their
own profile and password, only admins may create accounts, change roles, grant project
access, or delete accounts, and the seeded default account keeps its protections.
"""
function _handle_users_post(ctx::PageContext, request::HTTP.Request)::HTTP.Response
    viewer = ctx.viewer
    fields = _form_fields(request)
    path = ctx.path
    if path == "/users"
        viewer.is_admin || return _redirect(_with_flash("/", "err", "forbidden"))
        _post_allowed(request, fields) ||
            return _redirect(_with_flash("/users", "err", "csrf"))
        return _create_user_from_form(fields)
    end
    m = match(_USER_PATTERN, path)
    isnothing(m) && return HTTP.Response(404, "Not found")
    user = get_user(String(m[1]))
    isnothing(user) && return HTTP.Response(404, "Not found")
    action = something(m[2], "")
    back = _user_url(user.id)
    is_self = viewer.id == user.id
    (viewer.is_admin || is_self) || return _redirect(_with_flash("/", "err", "forbidden"))
    _post_allowed(request, fields) || return _redirect(_with_flash(back, "err", "csrf"))

    if action == "profile"
        result = update_user(
            user.id,
            get(fields, "first_name", ""),
            get(fields, "last_name", ""),
            nothing,
            nothing,
        )
        return _redirect(
            if result === Updated
                _with_flash(back, "ok", "profile")
            else
                _with_flash(back, "err", "invalid")
            end,
        )
    elseif action == "password"
        password = get(fields, "password", "")
        isempty(password) && return _redirect(_with_flash(back, "err", "password_empty"))
        password == get(fields, "password_confirm", "") ||
            return _redirect(_with_flash(back, "err", "password_mismatch"))
        result = update_user(user.id, nothing, nothing, password, nothing)
        return _redirect(
            if result === Updated
                _with_flash(back, "ok", "password")
            else
                _with_flash(back, "err", "invalid")
            end,
        )
    elseif action == "role"
        viewer.is_admin || return _redirect(_with_flash(back, "err", "forbidden"))
        is_self && return _redirect(_with_flash(back, "err", "self"))
        wants_admin = haskey(fields, "is_admin")
        if user.username == "default" && !wants_admin
            return _redirect(_with_flash(back, "err", "default_user"))
        end
        result = update_user(user.id, nothing, nothing, nothing, wants_admin)
        return _redirect(
            if result === Updated
                _with_flash(back, "ok", "role")
            else
                _with_flash(back, "err", "invalid")
            end,
        )
    elseif action == "permissions"
        viewer.is_admin || return _redirect(_with_flash(back, "err", "forbidden"))
        _apply_permissions(user, fields)
        return _redirect(_with_flash(back, "ok", "permissions"))
    elseif action == "delete"
        viewer.is_admin || return _redirect(_with_flash(back, "err", "forbidden"))
        is_self && return _redirect(_with_flash(back, "err", "self"))
        user.username == "default" &&
            return _redirect(_with_flash(back, "err", "default_user"))
        delete_user(user.id) || return _redirect(_with_flash(back, "err", "invalid"))
        return _redirect(_with_flash("/users", "ok", "deleted"))
    end
    return HTTP.Response(404, "Not found")
end

function _create_user_from_form(fields::AbstractDict)::HTTP.Response
    username = strip(get(fields, "username", ""))
    password = get(fields, "password", "")
    isempty(username) && return _redirect(_with_flash("/users", "err", "username"))
    isempty(password) && return _redirect(_with_flash("/users", "err", "password_empty"))
    id, status = create_user(
        get(fields, "first_name", ""), get(fields, "last_name", ""), username, password
    )
    status === Duplicate && return _redirect(_with_flash("/users", "err", "duplicate"))
    (status === Created && !isnothing(id)) ||
        return _redirect(_with_flash("/users", "err", "invalid"))
    haskey(fields, "is_admin") && update_user(id, nothing, nothing, nothing, true)
    return _redirect(_with_flash(_user_url(id), "ok", "created"))
end

# One checkbox per project and action; a project with no box checked loses its row.
function _apply_permissions(user::User, fields::AbstractDict)
    existing = Dict(p.project_id => p for p in get_userpermissions(User, user.id))
    for project in get_projects()
        flag(action) = haskey(fields, "perm:$(project.id):$(action)")
        create, read, update_flag, delete_flag = flag("create"),
        flag("read"), flag("update"),
        flag("delete")
        permission = get(existing, project.id, nothing)
        if create || read || update_flag || delete_flag
            if isnothing(permission)
                create_userpermission(
                    user.id, project.id, create, read, update_flag, delete_flag
                )
            else
                update_userpermission(permission.id, create, read, update_flag, delete_flag)
            end
        elseif !isnothing(permission)
            delete_userpermission(permission.id)
        end
    end
    return nothing
end

_permission_flags(::Nothing) = (false, false, false, false)
function _permission_flags(permission::UserPermission)
    return (
        permission.read_permission,
        permission.create_permission,
        permission.update_permission,
        permission.delete_permission,
    )
end
