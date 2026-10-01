"""
    start_ui_server(host::AbstractString, port::Integer)::Bonito.HTTPServer.Server

Boot the embedded DearDiary dashboard on `host:port`. The server runs in a sibling task
alongside the REST API server so a single `DearDiary.run` call exposes both endpoints on
different ports.

Pages are plain HTTP handlers (see [`render_page`](@ref)); no Bonito session or JavaScript
bundle is involved, so booting needs neither a browser nor a bundler. When
`DEARDIARY_ENABLE_AUTH` is on, `/login` and `/logout` manage the session cookie the other
pages require.

Call [`stop_ui_server`](@ref) to shut it down. `DearDiary.stop` closes both the REST and
UI servers together.

# Arguments
- `host::AbstractString`: Interface to bind.
- `port::Integer`: Port to listen on.

# Returns
The running [`Bonito.HTTPServer.Server`](https://simondanisch.github.io/Bonito.jl/).
"""
function start_ui_server(host::AbstractString, port::Integer)::Bonito.HTTPServer.Server
    server = Bonito.Server(string(host), Int(port); verbose=-1)
    Bonito.HTTPServer.route!(server, "/" => _handle_page)
    Bonito.HTTPServer.route!(server, "/favicon.ico" => _serve_favicon_ico)
    Bonito.HTTPServer.route!(server, "/login" => _handle_login)
    Bonito.HTTPServer.route!(server, "/logout" => _handle_logout)
    Bonito.HTTPServer.route!(server, "/users" => _handle_page)
    Bonito.HTTPServer.route!(server, "/settings" => _handle_page)
    Bonito.HTTPServer.route!(server, _USER_PATTERN => _handle_page)
    Bonito.HTTPServer.route!(server, _PAGE_PATTERN => _handle_page)
    Bonito.HTTPServer.route!(server, _ENTITY_POST_PATTERN => _handle_page)
    Bonito.HTTPServer.route!(server, _DOWNLOAD_PATTERN => _handle_download)
    Bonito.HTTPServer.route!(server, r"^/static/.+" => _handle_static)
    # Registered last so every more specific route above wins; anything else gets the
    # dashboard's own not-found page.
    Bonito.HTTPServer.route!(server, r"^/.*" => _handle_page)
    @info "DearDiary UI running on http://$(host):$(port)"
    return server
end

"""
    stop_ui_server(server::Optional{Bonito.HTTPServer.Server})::Nothing

Shut down the UI server.

# Arguments
- `server`: The instance [`start_ui_server`](@ref) returned, or `nothing` to do nothing so
  `DearDiary.stop` need not check whether the UI ever booted.
"""
function stop_ui_server(server::Optional{Bonito.HTTPServer.Server})::Nothing
    if !(isnothing(server))
        try
            close(server)
        catch err
            @warn "Error while closing the DearDiary UI server" exception = err
        end
    end
    return nothing
end
