"""
The embedded dashboard. Every page is rendered server-side from the service layer and
served as a self-contained HTML document: the stylesheet and script in `assets/ui/` are
inlined, and only fonts, the logo, and artifact downloads go through extra requests.

[`render_page`](@ref) maps a URL path to a page, and the `_handle_*` functions below adapt
that to the HTTP handlers [`start_ui_server`](@ref) registers. Sessions and sign-in live in
`auth.jl`; user management in `pages/users.jl`.
"""
const _ASSETS_DIR = normpath(joinpath(@__DIR__, "..", "..", "assets"))
const _LOGO_PATH = joinpath(_ASSETS_DIR, "logo.svg")
# Both files are baked into the precompiled module; declaring them as dependencies makes
# Julia recompile when they change, which a plain `read` at load time would not.
include_dependency(joinpath(_ASSETS_DIR, "ui", "dashboard.css"))
include_dependency(joinpath(_ASSETS_DIR, "ui", "dashboard.js"))
const _UI_CSS = read(joinpath(_ASSETS_DIR, "ui", "dashboard.css"), String)
const _UI_JS = read(joinpath(_ASSETS_DIR, "ui", "dashboard.js"), String)

# Applies a stored theme choice before the first paint so the page never flashes the
# wrong colour scheme.
const _THEME_BOOT_JS = "try{var t=localStorage.getItem('dd-theme');if(t==='dark'||t==='light'){document.documentElement.setAttribute('data-theme',t)}}catch(e){}"

# Files reachable under /static/, keyed by their relative path.
const _STATIC_FILES = Dict{String,Tuple{String,String}}(
    "logo.svg" => (_LOGO_PATH, "image/svg+xml"),
    "fonts/instrument-sans.woff2" =>
        (joinpath(_ASSETS_DIR, "ui", "fonts", "instrument-sans.woff2"), "font/woff2"),
    "fonts/juliamono-regular.woff2" =>
        (joinpath(_ASSETS_DIR, "ui", "fonts", "juliamono-regular.woff2"), "font/woff2"),
    "fonts/juliamono-medium.woff2" =>
        (joinpath(_ASSETS_DIR, "ui", "fonts", "juliamono-medium.woff2"), "font/woff2"),
    "fonts/juliamono-bold.woff2" =>
        (joinpath(_ASSETS_DIR, "ui", "fonts", "juliamono-bold.woff2"), "font/woff2"),
)

const _PAGE_PATTERN = r"^/(project|experiment|iteration|model)/([^/?#]+)/?$"
const _DOWNLOAD_PATTERN = r"^/resource/([^/?#]+)/download/?$"

_default_viewer()::Optional{User} = get_user_by_username("default")

function _can_read(viewer::User, project_id::Optional{AbstractString})::Bool
    isnothing(project_id) && return false
    viewer.is_admin && return true
    return any(
        p -> p.project_id == project_id && p.read_permission,
        get_userpermissions(User, viewer.id),
    )
end

"""
    render_page(path::AbstractString, ctx::PageContext)::Tuple{Int,String}
    render_page(path::AbstractString)::Tuple{Int,String}

Render the dashboard page at `path` (for example `/` or `/iteration/<id>`) for the viewer
in `ctx` and return the HTTP status with the HTML document. The one-argument form renders
as the seeded `default` user. Unknown paths and ids the viewer cannot read render the
not-found page, admin-only pages render a forbidden page for members, and a rendering
error renders the error page with status 500.
"""
function render_page(path::AbstractString, ctx::PageContext)::Tuple{Int,String}
    page = try
        _route(path, ctx)
    catch err
        @error "DearDiary UI failed to render $(path)" exception = (err, catch_backtrace())
        _error_page(err)
    end
    return (page.status, _render_document(page, ctx))
end

function render_page(path::AbstractString)::Tuple{Int,String}
    viewer = _default_viewer()
    if isnothing(viewer)
        page = _no_viewer_page()
        return (page.status, _render_document(page, nothing; current_path=path))
    end
    return render_page(path, PageContext(viewer; path=path))
end

function _route(path::AbstractString, ctx::PageContext)::Page
    viewer = ctx.viewer
    path == "/" && return _render_home(viewer)
    path == "/users" && return (viewer.is_admin ? _render_users(ctx) : _forbidden_page())
    path == "/settings" && return _render_user(ctx, viewer)
    user_match = match(_USER_PATTERN, path)
    if !isnothing(user_match) && isnothing(user_match[2])
        user = get_user(String(user_match[1]))
        isnothing(user) && return _not_found_page(path)
        (viewer.is_admin || viewer.id == user.id) || return _forbidden_page()
        return _render_user(ctx, user)
    end
    m = match(_PAGE_PATTERN, path)
    isnothing(m) && return _not_found_page(path)
    kind, id = m[1], String(m[2])
    if kind == "project"
        project = get_project(id)
        (isnothing(project) || !_can_read(viewer, project.id)) &&
            return _not_found_page(path)
        return _render_project(project, ctx)
    elseif kind == "experiment"
        experiment = get_experiment(id)
        (isnothing(experiment) || !_can_read(viewer, experiment.project_id)) &&
            return _not_found_page(path)
        return _render_experiment(experiment, ctx)
    elseif kind == "iteration"
        iteration = get_iteration(id)
        (isnothing(iteration) || !_can_read(viewer, get_project_id(iteration))) &&
            return _not_found_page(path)
        return _render_iteration(iteration, ctx)
    else
        model = get_model(id)
        (isnothing(model) || !_can_read(viewer, model.project_id)) &&
            return _not_found_page(path)
        return _render_model(model, ctx)
    end
end

function _message_page(
    title::AbstractString,
    heading::AbstractString,
    children...;
    status::Integer,
    crumb::AbstractString,
)::Page
    body = DOM.div(DOM.h1(heading; class="dd-title"), children...; class="dd-notfound")
    return Page(title, Any["Projects" => "/", crumb => nothing], Any[body]; status=status)
end

function _not_found_page(path::AbstractString)::Page
    return _message_page(
        "Not found · DearDiary",
        "Page not found",
        DOM.p(
            "Nothing is recorded at ",
            DOM.code(path),
            ". The entry may have been deleted, or the link may be stale.",
        ),
        DOM.p(_link("Back to projects", "/"));
        status=404,
        crumb="Not found",
    )
end

function _forbidden_page()::Page
    return _message_page(
        "Forbidden · DearDiary",
        "Administrators only",
        DOM.p(
            "This page manages accounts and project access, which only administrators can do.",
        ),
        DOM.p(_link("Back to projects", "/"));
        status=403,
        crumb="Forbidden",
    )
end

function _error_page(err)::Page
    return _message_page(
        "Error · DearDiary",
        "The page could not be rendered",
        DOM.p("The server logged the full backtrace. The error was:"),
        _code(sprint(showerror, err));
        status=500,
        crumb="Error",
    )
end

function _no_viewer_page()::Page
    return _message_page(
        "DearDiary",
        "The default user is missing",
        DOM.p(
            "The dashboard reads as the seeded ",
            DOM.code("default"),
            " user, which no longer exists. Restart the server to re-seed it, or create the user through the REST API.",
        );
        status=500,
        crumb="Error",
    )
end

function _topbar(ctx::Optional{PageContext})
    brand = DOM.a(
        DOM.img(; src="/static/logo.svg", alt=""), "DearDiary"; href="/", class="dd-brand"
    )
    path = isnothing(ctx) ? "" : ctx.path
    links = Any[DOM.a(
        "Projects"; _attrs(; href="/", ariaCurrent=(path == "/" ? "page" : nothing))...
    )]
    if !isnothing(ctx) && ctx.viewer.is_admin
        push!(
            links,
            DOM.a(
                "Users";
                _attrs(;
                    href="/users",
                    ariaCurrent=(startswith(path, "/users") ? "page" : nothing),
                )...,
            ),
        )
    end
    push!(
        links,
        DOM.a(
            "Docs",
            DOM.span(" ↗"; ariaHidden="true");
            href=_DOCS_URL,
            target="_blank",
            rel="noopener noreferrer",
            class="dd-docs-link",
        ),
    )
    theme = DOM.button(
        DOM.span(_sun_icon(); class="dd-icon-sun"),
        DOM.span(_moon_icon(); class="dd-icon-moon");
        type="button",
        class="dd-theme-toggle",
        dataThemeToggle="true",
        ariaLabel="Toggle colour theme",
        title="Toggle theme",
    )
    push!(links, theme)
    if !isnothing(ctx)
        viewer = ctx.viewer
        push!(
            links,
            DOM.a(
                DOM.span(_initials(viewer); class="dd-avatar", ariaHidden="true"),
                DOM.span(_display_name(viewer); class="dd-viewer-name");
                href="/settings",
                class="dd-viewer",
                title="Account settings for $(viewer.username)",
            ),
        )
        if _auth_enabled()
            push!(
                links,
                _form(
                    "/logout",
                    ctx.csrf,
                    DOM.button("Sign out"; type="submit");
                    class="dd-signout",
                ),
            )
        end
    end
    return DOM.header(brand, DOM.nav(links...; class="dd-topnav"); class="dd-topbar")
end

function _footer()
    return DOM.footer(
        DOM.span("v$(pkgversion(DearDiary))"),
        DOM.span(
            _external_link("Documentation", _DOCS_URL),
            " · ",
            _external_link("Source", "https://github.com/JuliaAI/DearDiary.jl"),
        );
        class="dd-foot",
    )
end

function _render_document(
    page::Page, ctx::Optional{PageContext}; current_path::AbstractString=""
)::String
    head = DOM.head(
        DOM.meta(; charset="UTF-8"),
        DOM.meta(; name="viewport", content="width=device-width, initial-scale=1.0"),
        DOM.meta(; name="color-scheme", content="light dark"),
        DOM.title(page.title),
        DOM.link(; rel="icon", type="image/svg+xml", href="/favicon.ico"),
        DOM.script(_THEME_BOOT_JS),
        DOM.style(_UI_CSS),
    )
    main = if page.chrome
        DOM.main(
            isempty(page.crumbs) ? nothing : _crumbs(page.crumbs),
            page.body...,
            _footer();
            class="dd-page",
            id="content",
        )
    else
        DOM.main(page.body...; class="dd-page", id="content")
    end
    skip =
        page.chrome ? DOM.a("Skip to content"; href="#content", class="dd-skip") : nothing
    body = DOM.body(skip, page.chrome ? _topbar(ctx) : nothing, main, DOM.script(_UI_JS))
    document = DOM.html(head, body; lang="en")
    return "<!DOCTYPE html>" * sprint(show, MIME("text/html"), document)
end

# ---------- HTTP handlers ----------

_request_path(request::HTTP.Request)::String = String(HTTP.URI(request.target).path)

function _html_response(
    status::Integer, html::AbstractString; headers=Pair{String,String}[]
)::HTTP.Response
    return HTTP.Response(
        Int(status),
        vcat(
            ["Content-Type" => "text/html; charset=utf-8", "Cache-Control" => "no-store"],
            headers,
        );
        body=html,
    )
end

"""
    _page_context(request::HTTP.Request)::Optional{PageContext}

Resolve the viewer for a request, or `nothing` when authentication is on and the session
cookie is missing or stale.
"""
function _page_context(request::HTTP.Request)::Optional{PageContext}
    viewer = _session_user(request)
    isnothing(viewer) && return nothing
    return PageContext(
        viewer;
        path=_request_path(request),
        query=_query(request),
        csrf=_csrf_token(request),
    )
end

function _handle_page(context)::HTTP.Response
    request = context.request
    path = _request_path(request)
    ctx = _page_context(request)
    if isnothing(ctx)
        _auth_enabled() && return _redirect(_login_url(path))
        page = _no_viewer_page()
        return _html_response(
            page.status, _render_document(page, nothing; current_path=path)
        )
    end
    if request.method == "POST"
        (path == "/users" || !isnothing(match(_USER_PATTERN, path))) &&
            return _handle_users_post(ctx, request)
        isnothing(match(_ENTITY_POST_PATTERN, path)) ||
            return _handle_entity_post(ctx, request)
        return HTTP.Response(405, "Method not allowed")
    end
    status, html = render_page(path, ctx)
    return _html_response(status, html)
end

function _handle_static(context)::HTTP.Response
    path = _request_path(context.request)
    relative = startswith(path, "/static/") ? path[(length("/static/") + 1):end] : ""
    entry = get(_STATIC_FILES, relative, nothing)
    isnothing(entry) && return HTTP.Response(404, "Not found")
    file, mime = entry
    return HTTP.Response(
        200,
        ["Content-Type" => mime, "Cache-Control" => "public, max-age=86400"];
        body=read(file),
    )
end

"""
    _serve_favicon_ico(context)::HTTP.Response

Browsers request `/favicon.ico` on their own. Serve the package logo there so the request
resolves even though the page links the icon explicitly.
"""
function _serve_favicon_ico(_context)::HTTP.Response
    return HTTP.Response(
        200,
        ["Content-Type" => "image/svg+xml", "Cache-Control" => "public, max-age=86400"];
        body=read(_LOGO_PATH),
    )
end

# Only characters safe inside a quoted Content-Disposition filename survive.
function _safe_filename(name::AbstractString)::String
    cleaned = replace(name, r"[^A-Za-z0-9._ -]" => "_")
    return isempty(cleaned) ? "artifact" : cleaned
end

function _handle_download(context)::HTTP.Response
    request = context.request
    m = match(_DOWNLOAD_PATTERN, _request_path(request))
    isnothing(m) && return HTTP.Response(404, "Not found")
    viewer = _session_user(request)
    if isnothing(viewer)
        _auth_enabled() && return _redirect(_login_url(_request_path(request)))
        return HTTP.Response(404, "Not found")
    end
    resource = get_resource(String(m[1]))
    if isnothing(resource) || !_can_read(viewer, get_project_id(resource))
        return HTTP.Response(404, "Not found")
    end
    bytes = read_resource_data(resource.id)
    isnothing(bytes) && return HTTP.Response(404, "Artifact bytes are unavailable")
    return HTTP.Response(
        200,
        [
            "Content-Type" => "application/octet-stream",
            "Content-Disposition" => "attachment; filename=\"$(_safe_filename(resource.name))\"",
            "Cache-Control" => "no-store",
        ];
        body=bytes,
    )
end
