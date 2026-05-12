"""
    Client

Handle for talking to a running DearDiary REST API. Constructed via [`connect`](@ref).
The token, expiry, and cached user are mutable so [`refresh_token!`](@ref) and reauthentication
do not require rebuilding the client.

Fields
- `base_url::String`: Base URL of the server (e.g. `"http://127.0.0.1:9000"`), without trailing slash.
- `token::Optional{String}`: Bearer token, or `nothing` when the server runs with auth disabled.
- `expires_at::Optional{Int}`: Unix epoch seconds at which the token expires.
- `user::Optional{UserResponse}`: The signed-in user, if known.
"""
mutable struct Client
    base_url::String
    token::Optional{String}
    expires_at::Optional{Int}
    user::Optional{UserResponse}
end

"""
    ClientError <: Exception

Raised by [`Client`](@ref) methods when the server returns a non-2xx status.

Fields
- `status::Int`: The HTTP status code.
- `code::String`: The stable error code from the response body (`"NOT_FOUND"`, `"CONFLICT"`, …),
  or `"UNKNOWN"` when the body is unparseable.
- `message::String`: Human-readable description from the response body.
"""
struct ClientError <: Exception
    status::Int
    code::String
    message::String
end

function Base.showerror(io::IO, err::ClientError)
    print(io, "ClientError($(err.status), $(err.code |> repr)): $(err.message)")
end
