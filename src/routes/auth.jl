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
            return json(("message" => "User not found"); status=HTTP.StatusCodes.NOT_FOUND)
        end

        if !CompareHashAndPassword(user.password, parameters.payload.password)
            return json(
                ("message" => "Invalid credentials");
                status=HTTP.StatusCodes.UNAUTHORIZED,
            )
        end

        expires_at = ((now() + Hour(1)) |> datetime2unix |> floor) |> Int
        claims = Dict(
            "sub" => user.username,
            "id" => user.id,
            "exp" => expires_at,
        )
        jwt = JWT(; payload=claims)
        global _DEARDIARY_APICONFIG
        key = JWKSymmetric(
            JWTs.MD_SHA256,
            _DEARDIARY_APICONFIG.jwt_secret |> Array{UInt8,1},
        )
        sign!(jwt, key)

        return json(
            Dict(
                "access_token" => (jwt |> string),
                "token_type" => "Bearer",
                "expires_at" => expires_at,
                "user" => (user |> sanitize_user),
            );
            status=HTTP.StatusCodes.OK,
        )
    end
end
