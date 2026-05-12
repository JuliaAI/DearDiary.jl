"""
    connect(base_url; username, password, token)::Client

Build a [`Client`](@ref) pointed at `base_url`.

Pass `username` and `password` to sign in via `POST /auth` and store the issued token. Pass
`token` instead to attach an already-issued bearer token. Pass neither when the server runs
with auth disabled — the client will work without an `Authorization` header.

# Arguments
- `base_url::AbstractString`: Base URL of the server (with or without trailing slash).
- `username::Optional{AbstractString}`: Username for sign-in.
- `password::Optional{AbstractString}`: Password for sign-in.
- `token::Optional{AbstractString}`: Pre-issued bearer token.

# Returns
A [`Client`](@ref) ready to issue authenticated requests.
"""
function connect(
    base_url::AbstractString;
    username::Optional{AbstractString}=nothing,
    password::Optional{AbstractString}=nothing,
    token::Optional{AbstractString}=nothing,
)::Client
    cleaned = rstrip(base_url, '/') |> String
    client = Client(cleaned, nothing, nothing, nothing)

    if !(token |> isnothing)
        client.token = token |> String
        return client
    end

    if !(username |> isnothing) && !(password |> isnothing)
        envelope = _json(_request(
            client, "POST", "/auth";
            body=Dict("username" => username, "password" => password),
        ))
        client.token = envelope["access_token"] |> String
        client.expires_at = envelope["expires_at"]
        client.user = envelope["user"] |> UserResponse
    end

    return client
end

"""
    disconnect(client::Client)::Nothing

Clear the local token. The server is stateless so this is purely a client-side reset; any
copies of the token issued earlier remain valid until they expire.
"""
function disconnect(client::Client)::Nothing
    client.token = nothing
    client.expires_at = nothing
    client.user = nothing
    return nothing
end

"""
    refresh_token!(client::Client)::Client

Call `POST /auth/refresh` and replace the client's token with the freshly-minted one.
"""
function refresh_token!(client::Client)::Client
    envelope = _json(_request(client, "POST", "/auth/refresh"))
    client.token = envelope["access_token"] |> String
    client.expires_at = envelope["expires_at"]
    client.user = envelope["user"] |> UserResponse
    return client
end

"""
    whoami(client::Client)::UserResponse

Resolve the user behind the current token via `GET /auth/me`. Also refreshes the cached
`client.user`.
"""
function whoami(client::Client)::UserResponse
    user = _json(_request(client, "GET", "/auth/me")) |> UserResponse
    client.user = user
    return user
end
