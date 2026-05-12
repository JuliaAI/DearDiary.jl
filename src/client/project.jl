"""
    get_project(client::Client, id::Integer)::Optional{Project}

Fetch a [`Project`](@ref) via `GET /project/{id}` on the API behind `client`. Returns
`nothing` when the server replies 404 (record missing or viewer lacks
[`ReadPermission`](@ref)) and raises [`ClientError`](@ref) for other failures.
"""
function get_project(client::Client, id::Integer)::Optional{Project}
    try
        return _json(_request(client, "GET", "/project/$id")) |> Project
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_projects(client::Client)::Array{Project,1}

List every [`Project`](@ref) the authenticated viewer can read via `GET /project/`. Admins
receive every project; non-admins receive only those with [`ReadPermission`](@ref) granted.
"""
function get_projects(client::Client)::Array{Project,1}
    response = _request(client, "GET", "/project/")
    decoded = JSON.parse(response.body |> String)
    return [item |> Project for item in decoded]
end

"""
    create_project(client::Client, name::AbstractString)::Int64

Create a [`Project`](@ref) named `name` via `POST /project/`. The route requires an admin
viewer; non-admin callers receive `403 ADMIN_REQUIRED`. Returns the new project id.
"""
function create_project(client::Client, name::AbstractString)::Int64
    response = _request(
        client, "POST", "/project/"; body=Dict("name" => name),
    )
    return _json(response)["project_id"]
end

"""
    update_project(client::Client, id::Integer; name=nothing, description=nothing)::Nothing

Patch a [`Project`](@ref) via `PATCH /project/{id}`. Any keyword left as `nothing` is left
untouched server-side. Admin-only. Raises [`ClientError`](@ref) on failure.
"""
function update_project(
    client::Client, id::Integer;
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
)::Nothing
    _request(
        client, "PATCH", "/project/$id";
        body=Dict("name" => name, "description" => description),
    )
    return nothing
end

"""
    delete_project(client::Client, id::Integer)::Nothing

Delete a [`Project`](@ref) (cascading [`UserPermission`](@ref) and [`Experiment`](@ref)
records) via `DELETE /project/{id}`. Admin-only. Raises [`ClientError`](@ref) on failure.
"""
function delete_project(client::Client, id::Integer)::Nothing
    _request(client, "DELETE", "/project/$id")
    return nothing
end
