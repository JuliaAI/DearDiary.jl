@testset verbose = true "ui/server" begin
    @testset "stop_ui_server(nothing) is a no-op" begin
        @test DearDiary.stop_ui_server(nothing) === nothing
    end

    @testset "start_ui_server boots a working server" begin
        @with_deardiary_test_db begin
            # Bonito.Server stores whatever port we pass it verbatim, so port=0 leaves
            # the test client without a usable URL. Ask the OS for a free port via a
            # throwaway listener, close it, then hand the port to Bonito.
            probe = Sockets.listen(Sockets.IPv4("127.0.0.1"), 0)
            _, port_int = Sockets.getsockname(probe)
            port = UInt16(port_int)
            close(probe)

            server = DearDiary.start_ui_server("127.0.0.1", port)
            try
                sleep(0.5)

                favicon = HTTP.get(
                    "http://127.0.0.1:$(port)/favicon.ico"; status_exception=false,
                )
                @test favicon.status == 200
                @test HTTP.header(favicon, "Content-Type") == "image/svg+xml"
                @test favicon.body |> isempty == false

                root = HTTP.get(
                    "http://127.0.0.1:$(port)/"; status_exception=false,
                )
                @test root.status == 200

                html = root.body |> String
                @test occursin("<title", html)
                @test occursin("DearDiary", html)
                @test occursin("rel=\"icon\"", html)
                @test occursin("charset=\"UTF-8\"", html)
                @test occursin("dd-brand", html)
                @test occursin("dd-sidebar-footer", html)
                @test occursin("juliaai.github.io/DearDiary.jl/dev/", html)
                # The metrics chart renders as inline SVG; no external CDN script.
                @test !occursin("plotly", html |> lowercase)
                @test !occursin("cdn.plot.ly", html |> lowercase)
            finally
                DearDiary.stop_ui_server(server)
            end
        end
    end
end
