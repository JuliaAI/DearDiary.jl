const TOKEN_TTL_HOURS = 24

"""
    issue_token(user::User)::Dict{String,Any}

Mint a fresh JWT for `user` and assemble the standard auth response envelope.

# Arguments
- `user::User`: The authenticated user the token represents.

# Returns
A `Dict` with `access_token`, `token_type`, `expires_at` (Unix epoch seconds), and a
sanitized `user` payload — the same shape returned by `POST /auth` and `POST /auth/refresh`.
"""
function issue_token(user::User)::Dict{String,Any}
    global _DEARDIARY_APICONFIG
    expires_at = (
        (now() + Hour(TOKEN_TTL_HOURS)) |> datetime2unix |> floor
    ) |> Int
    claims = Dict(
        "sub" => user.username,
        "id" => user.id,
        "exp" => expires_at,
    )
    jwt = JWT(; payload=claims)
    key = JWKSymmetric(
        JWTs.MD_SHA256,
        _DEARDIARY_APICONFIG.jwt_secret |> Array{UInt8,1},
    )
    sign!(jwt, key)
    return Dict{String,Any}(
        "access_token" => (jwt |> string),
        "token_type" => "Bearer",
        "expires_at" => expires_at,
        "user" => (user |> sanitize_user),
    )
end

"""
    setup_auth_routes()

This function sets up the authentication-related routes for the API.

!!! warning
    This function is intended for internal use. Users should not call this function directly.
"""
function setup_auth_routes()
    root = router("/auth", tags=["auth"])

    @get root("/me") function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG
        if !_DEARDIARY_APICONFIG.enable_auth
            request.context[:user] = get(
                request.context, :user, get_user("default"),
            )
        end
        return json(
            (request.context[:user] |> sanitize_user); status=HTTP.StatusCodes.OK,
        )
    end

    @post root("/") function (::HTTP.Request, parameters::Json{UserLoginPayload})
        user = parameters.payload.username |> get_user

        if user |> isnothing
            return error_response(
                UserNotFound, "User not found"; status=HTTP.StatusCodes.NOT_FOUND,
            )
        end

        if !CompareHashAndPassword(user.password, parameters.payload.password)
            return error_response(
                InvalidCredentials, "Invalid credentials";
                status=HTTP.StatusCodes.UNAUTHORIZED,
            )
        end

        return json(user |> issue_token; status=HTTP.StatusCodes.OK)
    end

    @post root("/refresh") function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG
        user = if _DEARDIARY_APICONFIG.enable_auth
            request.context[:user]
        else
            get(request.context, :user, get_user("default"))
        end
        return json(user |> issue_token; status=HTTP.StatusCodes.OK)
    end
end
