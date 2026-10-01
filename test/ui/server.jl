@testset verbose = true "ui/server" begin
    @testset "stop_ui_server(nothing) is a no-op" begin
        @test DearDiary.stop_ui_server(nothing) === nothing
    end

    @testset "start_ui_server boots a working server" begin
        # The pages are plain HTTP handlers, but the Bonito server is still shared with
        # the runner's network stack; keep the live boot off headless CI.
        if get(ENV, "CI", "false") == "true"
            @test_skip "UI server boot is skipped on CI"
        else
            @with_deardiary_test_db begin
                # Bonito.Server stores whatever port we pass it verbatim, so port=0 leaves
                # the test client without a usable URL. Ask the OS for a free port via a
                # throwaway listener, close it, then hand the port to Bonito.
                probe = Sockets.listen(Sockets.IPv4("127.0.0.1"), 0)
                _, port_int = Sockets.getsockname(probe)
                port = UInt16(port_int)
                close(probe)

                user = DearDiary.get_user_by_username("default")
                project_id, _ = DearDiary.create_project(user.id, "ServerProject")

                server = DearDiary.start_ui_server("127.0.0.1", port)
                try
                    sleep(0.5)
                    base = "http://127.0.0.1:$(port)"

                    favicon = HTTP.get("$(base)/favicon.ico"; status_exception=false)
                    @test favicon.status == 200
                    @test HTTP.header(favicon, "Content-Type") == "image/svg+xml"

                    root = HTTP.get("$(base)/"; status_exception=false)
                    @test root.status == 200
                    @test HTTP.header(root, "Content-Type") == "text/html; charset=utf-8"
                    html = String(root.body)
                    @test occursin("<title>Projects · DearDiary</title>", html)
                    @test occursin("ServerProject", html)
                    @test occursin("charset=\"UTF-8\"", html)
                    @test occursin("dd-topbar", html)
                    @test occursin("juliaai.github.io/DearDiary.jl/dev/", html)
                    @test !occursin("<script src=", html)

                    project = HTTP.get(
                        "$(base)/project/$(project_id)"; status_exception=false
                    )
                    @test project.status == 200
                    @test occursin("ServerProject · DearDiary", String(project.body))

                    font = HTTP.get(
                        "$(base)/static/fonts/instrument-sans.woff2"; status_exception=false
                    )
                    @test font.status == 200
                    @test HTTP.header(font, "Content-Type") == "font/woff2"

                    missing = HTTP.get("$(base)/model/nope"; status_exception=false)
                    @test missing.status == 404
                    @test occursin("Not found · DearDiary", String(missing.body))

                    stray = HTTP.get("$(base)/no/such/page"; status_exception=false)
                    @test stray.status == 404
                finally
                    DearDiary.stop_ui_server(server)
                end
            end
        end
    end
end
