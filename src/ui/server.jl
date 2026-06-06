"""
    start_ui_server(host::AbstractString, port::Integer)::Bonito.HTTPServer.Server

Boot the embedded DearDiary dashboard on `host:port` and return the running
[`Bonito.HTTPServer.Server`](https://simondanisch.github.io/Bonito.jl/) instance. The
server runs in a sibling task alongside the REST API server so a single `DearDiary.run`
call exposes both endpoints on different ports.

Call [`stop_ui_server`](@ref) to shut it down. `DearDiary.stop` closes both the REST and
UI servers together.
"""
function start_ui_server(host::AbstractString, port::Integer)::Bonito.HTTPServer.Server
    app = build_ui_app()
    server = Bonito.Server(app, host |> string, port |> Int; verbose=-1)
    # Browsers auto-probe `/favicon.ico` before they finish parsing the rendered `<head>`.
    # Answering here suppresses the 404 in the dev console and lets browsers that ignore
    # non-`/favicon.ico` declarations pick up the logo.
    Bonito.HTTPServer.route!(server, "/favicon.ico" => _serve_favicon_ico)
    @info "DearDiary UI running on http://$(host):$(port)"
    return server
end

"""
    stop_ui_server(server::Optional{Bonito.HTTPServer.Server})::Nothing

Shut down the UI server. Pass the [`Bonito.HTTPServer.Server`](@ref) instance that
[`start_ui_server`](@ref) returned, or pass `nothing` to skip the call so `DearDiary.stop`
need not check whether the UI ever booted.
"""
function stop_ui_server(server::Optional{Bonito.HTTPServer.Server})::Nothing
    if !(server |> isnothing)
        try
            server |> close
        catch err
            @warn "Error while closing the DearDiary UI server" exception=err
        end
    end
    return nothing
end
