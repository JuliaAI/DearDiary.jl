"""
    get_user(client::Client, id::AbstractString)::Optional{UserResponse}

Fetch a [`User`](@ref) (sanitized as [`UserResponse`](@ref), no password hash) via
`GET /user/{id}`. Returns `nothing` when the server replies 404 and raises
[`ClientError`](@ref) for other failures. The viewer must be `id` or an admin.

The username-based local lookup ([`get_user_by_username`](@ref)) has no REST counterpart;
iterate [`get_users`](@ref) and filter when a username lookup is required.
"""
function get_user(client::Client, id::AbstractString)::Optional{UserResponse}
    try
        return UserResponse(_json(_request(client, "GET", "/user/$id")))
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_users(client::Client)::Array{UserResponse,1}

List every user via `GET /user/`. Admin-only route; the returned [`UserResponse`](@ref)
values never include password hashes.
"""
function get_users(client::Client)::Array{UserResponse,1}
    response = _request(client, "GET", "/user/")
    decoded = JSON.parse(String(response.body))
    return [UserResponse(item) for item in decoded]
end

"""
    create_user(client::Client, first_name, last_name, username, password)::String

Create a [`User`](@ref) via `POST /user/`. Admin-only. Returns the new user id. Raises
[`ClientError`](@ref) with code `"CONFLICT"` when `username` is already taken.
"""
function create_user(
    client::Client,
    first_name::AbstractString,
    last_name::AbstractString,
    username::AbstractString,
    password::AbstractString,
)::String
    response = _request(
        client,
        "POST",
        "/user/";
        body=Dict(
            "first_name" => first_name,
            "last_name" => last_name,
            "username" => username,
            "password" => password,
        ),
    )
    return _json(response)["user_id"]
end

"""
    update_user(client::Client, id::AbstractString; first_name=nothing, last_name=nothing, password=nothing, is_admin=nothing)::Nothing

Patch a [`User`](@ref) via `PATCH /user/{id}`. Any keyword left as `nothing` is left
untouched server-side. The viewer must be `id` or an admin.
"""
function update_user(
    client::Client,
    id::AbstractString;
    first_name::Optional{AbstractString}=nothing,
    last_name::Optional{AbstractString}=nothing,
    password::Optional{AbstractString}=nothing,
    is_admin::Optional{Bool}=nothing,
)::Nothing
    _request(
        client,
        "PATCH",
        "/user/$id";
        body=Dict(
            "first_name" => first_name,
            "last_name" => last_name,
            "password" => password,
            "is_admin" => is_admin,
        ),
    )
    return nothing
end

"""
    delete_user(client::Client, id::AbstractString)::Nothing

Delete a [`User`](@ref) via `DELETE /user/{id}`. The viewer must be `id` or an admin; the
seeded `default` user cannot be removed (the server rejects the request).
"""
function delete_user(client::Client, id::AbstractString)::Nothing
    _request(client, "DELETE", "/user/$id")
    return nothing
end
