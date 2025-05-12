"""
    auth_handler(request::HTTP.Request, parameters::Json{UserLoginPayload})::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
function auth_handler(::HTTP.Request, parameters::Json{UserLoginPayload})::HTTP.Response
    user = parameters.payload.username |> get_user_by_username

    if user |> isnothing
        return json(("message" => "User not found"); status=HTTP.StatusCodes.NOT_FOUND)
    end

    if !CompareHashAndPassword(user.password, parameters.payload.password)
        return json(("message" => "Invalid credentials");
            status=HTTP.StatusCodes.UNAUTHORIZED)
    end

    claims = Dict(
        "sub" => user.username,
        "id" => user.id,
        "exp" => (now() + Hour(1)) |> Dates.value
    )
    encoding = JSONWebTokens.HS256(api_config.jwt_secret)
    token = JSONWebTokens.encode(encoding, claims)

    return json(token; status=HTTP.StatusCodes.OK)
end
