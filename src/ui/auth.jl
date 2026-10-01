# Browser sessions for the dashboard. The REST API authenticates with bearer tokens; the
# dashboard carries the same JWT in an HttpOnly cookie so pages can resolve the viewer
# without any JavaScript. With `DEARDIARY_ENABLE_AUTH=false` every request acts as the
# seeded `default` admin, mirroring the REST middlewares.

const _SESSION_COOKIE = "dd_session"
const _CSRF_FIELD = "csrf"

_auth_enabled()::Bool = !isnothing(_DEARDIARY_APICONFIG) && _DEARDIARY_APICONFIG.enable_auth

_jwt_secret()::String =
    isnothing(_DEARDIARY_APICONFIG) ? "" : _DEARDIARY_APICONFIG.jwt_secret

function _cookies(request::HTTP.Request)::Dict{String,String}
    out = Dict{String,String}()
    for (name, header) in request.headers
        lowercase(name) == "cookie" || continue
        for part in split(header, ';')
            kv = split(strip(part), '='; limit=2)
            length(kv) == 2 && (out[String(kv[1])] = String(kv[2]))
        end
    end
    return out
end

"""
    _session_token(request::HTTP.Request)::Optional{String}

The JWT carried by the dashboard session cookie, or `nothing` when absent.
"""
_session_token(request::HTTP.Request)::Optional{String} =
    get(_cookies(request), _SESSION_COOKIE, nothing)

"""
    _token_user(token::AbstractString)::Optional{User}

Validate a JWT against the configured secret and return its user. Signature, expiry, and
claim checks match the REST `AuthMiddleware`; any failure yields `nothing`.
"""
function _token_user(token::AbstractString)::Optional{User}
    isempty(token) && return nothing
    jwt = try
        JWT(; jwt=String(token))
    catch
        return nothing
    end
    key = JWKSymmetric("HS256", Vector{UInt8}(_jwt_secret()))
    try
        validate!(jwt, key)
    catch
        return nothing
    end
    isvalid(jwt) || return nothing
    payload = claims(jwt)
    isnothing(payload) && return nothing
    exp = get(payload, "exp", nothing)
    (exp isa Integer && exp >= floor(Int, datetime2unix(now()))) || return nothing
    user_id = get(payload, "id", nothing)
    (user_id isa AbstractString && !isempty(user_id)) || return nothing
    return get_user(user_id)
end

"""
    _session_user(request::HTTP.Request)::Optional{User}

The viewer behind a request: the seeded `default` user when authentication is off,
otherwise the user named by a valid session cookie, or `nothing`.
"""
function _session_user(request::HTTP.Request)::Optional{User}
    _auth_enabled() || return get_user_by_username("default")
    token = _session_token(request)
    isnothing(token) && return nothing
    return _token_user(token)
end

# Browsers send the cookie back on same-site navigations only (SameSite=Strict), which
# already blocks cross-site form posts; the CSRF token is a second check on every POST.
function _session_cookie(token::AbstractString)::String
    max_age = TOKEN_TTL_HOURS * 3600
    return "$(_SESSION_COOKIE)=$(token); Path=/; HttpOnly; SameSite=Strict; Max-Age=$(max_age)"
end

_clear_session_cookie()::String =
    "$(_SESSION_COOKIE)=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0"

"""
    _csrf_token(request::HTTP.Request)::String

A per-session token embedded in every form and checked on every POST. It is an HMAC of the
session token, so it cannot be forged without the secret and changes with each sign-in.
With authentication off there is no session, so the token is derived from a fixed seed.
"""
function _csrf_token(request::HTTP.Request)::String
    seed = something(_session_token(request), "default")
    digest = hmac_sha256(Vector{UInt8}("deardiary-csrf:" * _jwt_secret()), seed)
    return bytes2hex(digest)[1:32]
end

function _form_fields(request::HTTP.Request)::Dict{String,String}
    body = String(copy(request.body))
    isempty(body) && return Dict{String,String}()
    return Dict{String,String}(
        String(k) => String(v) for (k, v) in HTTP.URIs.queryparams(body)
    )
end

"""
    _post_allowed(request::HTTP.Request, fields)::Bool

Accept a form post only when it carries the session's CSRF token and the browser does not
mark it as cross-site.
"""
function _post_allowed(request::HTTP.Request, fields::AbstractDict)::Bool
    site = HTTP.header(request, "Sec-Fetch-Site", "")
    (site in ("", "same-origin", "none")) || return false
    return get(fields, _CSRF_FIELD, "") == _csrf_token(request)
end

_query(request::HTTP.Request)::Dict{String,String} = Dict{String,String}(
    String(k) => String(v) for (k, v) in HTTP.URIs.queryparams(HTTP.URI(request.target))
)

# Only same-origin paths survive, so a crafted `next` cannot bounce a user elsewhere.
function _safe_next(target::Optional{AbstractString})::String
    isnothing(target) && return "/"
    (startswith(target, "/") && !startswith(target, "//")) || return "/"
    return String(target)
end

function _redirect(location::AbstractString; headers=Pair{String,String}[])::HTTP.Response
    return HTTP.Response(303, vcat(["Location" => String(location)], headers); body="")
end

_login_url(next::AbstractString)::String =
    next == "/" ? "/login" : "/login?next=" * HTTP.URIs.escapeuri(next)

"""
    _handle_login(context)::HTTP.Response

`GET /login` renders the sign-in form; `POST /login` checks the credentials the same way
`POST /auth` does and, on success, sets the session cookie and redirects to `next`.
"""
function _handle_login(context)::HTTP.Response
    request = context.request
    _auth_enabled() || return _redirect("/")
    query = _query(request)
    next = _safe_next(get(query, "next", nothing))
    if request.method == "POST"
        fields = _form_fields(request)
        next = _safe_next(get(fields, "next", next))
        username = strip(get(fields, "username", ""))
        password = get(fields, "password", "")
        user = isempty(username) ? nothing : get_user_by_username(username)
        if isnothing(user) || !CompareHashAndPassword(user.password, password)
            page = _login_page(
                next; error="The username or password is not right.", username=username
            )
            return _html_response(
                401, _render_document(page, nothing; current_path="/login")
            )
        end
        token = issue_token(user)["access_token"]
        return _redirect(next; headers=["Set-Cookie" => _session_cookie(token)])
    end
    if !isnothing(_session_user(request))
        return _redirect(next)
    end
    page = _login_page(next)
    return _html_response(200, _render_document(page, nothing; current_path="/login"))
end

"""
    _handle_logout(context)::HTTP.Response

`POST /logout` clears the session cookie. The CSRF token is required like any other post.
"""
function _handle_logout(context)::HTTP.Response
    request = context.request
    request.method == "POST" || return _redirect("/")
    fields = _form_fields(request)
    _post_allowed(request, fields) || return _redirect("/")
    return _redirect("/login"; headers=["Set-Cookie" => _clear_session_cookie()])
end

function _login_page(
    next::AbstractString;
    error::Optional{AbstractString}=nothing,
    username::AbstractString="",
)::Page
    form = DOM.form(
        if isnothing(error)
            nothing
        else
            DOM.div(error; class="dd-banner dd-banner--err", role="alert")
        end,
        DOM.input(; type="hidden", name="next", value=next),
        _field(
            "Username",
            DOM.input(;
                type="text",
                name="username",
                class="dd-input",
                value=username,
                autocomplete="username",
                required="required",
                autofocus="autofocus",
            ),
        ),
        _field(
            "Password",
            DOM.input(;
                type="password",
                name="password",
                class="dd-input",
                autocomplete="current-password",
                required="required",
            ),
        ),
        DOM.button("Sign in"; type="submit", class="dd-btn dd-btn--primary");
        method="post",
        action="/login",
        class="dd-form",
    )
    card = DOM.div(
        DOM.div(
            DOM.img(; src="/static/logo.svg", alt=""), "DearDiary"; class="dd-login-brand"
        ),
        DOM.h1("Sign in"),
        DOM.p("Use the account your DearDiary administrator created for you."),
        form;
        class="dd-login",
    )
    return Page("Sign in · DearDiary", Any[], Any[card]; chrome=false)
end
