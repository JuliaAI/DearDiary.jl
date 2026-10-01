# Runs while the test server is up with authentication enabled, so `_DEARDIARY_APICONFIG`
# carries `enable_auth = true` and the test JWT secret.

function _ui_login(username, password)
    body = "username=$(HTTP.URIs.escapeuri(username))&password=$(HTTP.URIs.escapeuri(password))"
    request = HTTP.Request(
        "POST", "/login", ["Content-Type" => "application/x-www-form-urlencoded"], body
    )
    return DearDiary._handle_login((request=request,))
end

function _ui_cookie(response)
    header = HTTP.header(response, "Set-Cookie")
    return String(first(split(header, ';')))
end

@testset verbose = true "ui/auth" begin
    @test DearDiary._auth_enabled()

    @testset "pages redirect to sign-in without a session" begin
        @with_deardiary_test_db begin
            home = DearDiary._handle_page((request=HTTP.Request("GET", "/"),))
            @test home.status == 303
            @test HTTP.header(home, "Location") == "/login"
            deep = DearDiary._handle_page((request=HTTP.Request("GET", "/project/abc"),))
            @test HTTP.header(deep, "Location") == "/login?next=%2Fproject%2Fabc"
            download = DearDiary._handle_download((
                request=HTTP.Request("GET", "/resource/abc/download"),
            ))
            @test download.status == 303
            stale = HTTP.Request("GET", "/", ["Cookie" => "dd_session=not-a-token"])
            @test DearDiary._session_user(stale) === nothing
            @test DearDiary._handle_page((request=stale,)).status == 303
        end
    end

    @testset "sign-in form and session cookie" begin
        @with_deardiary_test_db begin
            form = DearDiary._handle_login((
                request=HTTP.Request("GET", "/login?next=%2Fusers"),
            ))
            @test form.status == 200
            html = String(form.body)
            @test occursin("<title>Sign in · DearDiary</title>", html)
            @test occursin("name=\"username\"", html)
            @test occursin("name=\"password\"", html)
            @test occursin("value=\"/users\"", html)
            @test !occursin("class=\"dd-topbar\"", html)

            wrong = _ui_login("default", "nope")
            @test wrong.status == 401
            @test occursin("not right", String(wrong.body))
            @test _ui_login("ghost", "nope").status == 401

            ok = _ui_login("default", "default")
            @test ok.status == 303
            @test HTTP.header(ok, "Location") == "/"
            cookie = _ui_cookie(ok)
            @test startswith(cookie, "dd_session=")
            @test occursin("HttpOnly", HTTP.header(ok, "Set-Cookie"))
            @test occursin("SameSite=Strict", HTTP.header(ok, "Set-Cookie"))

            signed_in = HTTP.Request("GET", "/", ["Cookie" => cookie])
            @test DearDiary._session_user(signed_in).username == "default"
            home = DearDiary._handle_page((request=signed_in,))
            @test home.status == 200
            body = String(home.body)
            @test occursin("action=\"/logout\"", body)
            @test occursin("Sign out", body)
            @test occursin("href=\"/users\"", body)

            # A signed-in visitor skips the form.
            again = DearDiary._handle_login((
                request=HTTP.Request("GET", "/login", ["Cookie" => cookie]),
            ))
            @test again.status == 303

            csrf = DearDiary._csrf_token(signed_in)
            logout = DearDiary._handle_logout((
                request=HTTP.Request(
                    "POST", "/logout", ["Cookie" => cookie], "csrf=$(csrf)"
                ),
            ))
            @test logout.status == 303
            @test occursin("Max-Age=0", HTTP.header(logout, "Set-Cookie"))
            no_token = DearDiary._handle_logout((
                request=HTTP.Request("POST", "/logout", ["Cookie" => cookie], ""),
            ))
            @test HTTP.header(no_token, "Set-Cookie", "") == ""
        end
    end

    @testset "expired and foreign tokens are rejected" begin
        @with_deardiary_test_db begin
            user = DearDiary.get_user_by_username("default")
            expired = JWT(;
                payload=Dict("sub" => user.username, "id" => user.id, "exp" => 1)
            )
            sign!(expired, JWKSymmetric("HS256", Vector{UInt8}("testsecret")))
            @test DearDiary._token_user(string(expired)) === nothing
            foreign = JWT(;
                payload=Dict(
                    "sub" => user.username, "id" => user.id, "exp" => 4_102_444_800
                ),
            )
            sign!(foreign, JWKSymmetric("HS256", Vector{UInt8}("othersecret")))
            @test DearDiary._token_user(string(foreign)) === nothing
            valid = DearDiary.issue_token(user)["access_token"]
            @test DearDiary._token_user(valid).id == user.id
        end
    end

    @testset "members see only their projects and settings" begin
        @with_deardiary_test_db begin
            admin = DearDiary.get_user_by_username("default")
            visible, _ = DearDiary.create_project(admin.id, "Visible")
            DearDiary.create_project(admin.id, "Hidden")
            alice_id, _ = DearDiary.create_user("Ada", "Lovelace", "alice", "wonderland")
            DearDiary.create_userpermission(alice_id, visible, false, true, false, false)
            cookie = _ui_cookie(_ui_login("alice", "wonderland"))
            get(path) = DearDiary._handle_page((
                request=HTTP.Request("GET", path, ["Cookie" => cookie]),
            ))
            home = get("/")
            @test home.status == 200
            @test occursin("Visible", String(home.body))
            @test !occursin("Hidden", String(home.body))
            @test !occursin("href=\"/users\"", String(home.body))
            @test get("/users").status == 403
            @test get("/settings").status == 200
            @test get("/users/$(admin.id)").status == 403
        end
    end
end
