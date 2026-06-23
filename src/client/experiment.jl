"""
    get_experiment(client::Client, id::Integer)::Optional{Experiment}

Fetch an [`Experiment`](@ref) via `GET /experiment/{id}`. Returns `nothing` when the
server replies 404 (record missing or viewer lacks [`ReadPermission`](@ref) on the owning
project) and raises [`ClientError`](@ref) for other failures.
"""
function get_experiment(client::Client, id::Integer)::Optional{Experiment}
    try
        return Experiment(_json(_request(client, "GET", "/experiment/$id")))
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_experiments(client::Client, project_id::Integer)::Array{Experiment,1}

Returns the first page (default limit) of [`Experiment`](@ref) records under `project_id`,
discarding the pagination envelope.
"""
function get_experiments(client::Client, project_id::Integer)::Array{Experiment,1}
    return get_experiments(client, project_id, Pagination(50, 0)).data
end

"""
    get_experiments(client::Client, project_id::Integer, page::Pagination)::PaginatedResponse{Experiment}

Fetch a page of [`Experiment`](@ref) records under `project_id` via
`GET /experiment/project/{project_id}?limit=…&offset=…`. Requires
[`ReadPermission`](@ref) on the project.
"""
function get_experiments(
    client::Client, project_id::Integer, page::Pagination
)::PaginatedResponse{Experiment}
    response = _request(
        client,
        "GET",
        "/experiment/project/$project_id";
        query=Dict("limit" => page.limit, "offset" => page.offset),
    )
    return _paginated(Experiment, _json(response))
end

"""
    create_experiment(client::Client, project_id::Integer, status_id::Integer, name::AbstractString)::Int64

Create an [`Experiment`](@ref) under `project_id` via `POST /experiment/project/{project_id}`.
`status_id` must equal `Integer(IN_PROGRESS)`; the server rejects experiments created already terminated. Requires [`CreatePermission`](@ref) on the project. Returns
the new experiment id.
"""
function create_experiment(
    client::Client, project_id::Integer, status_id::Integer, name::AbstractString
)::Int64
    response = _request(
        client,
        "POST",
        "/experiment/project/$project_id";
        body=Dict("status_id" => status_id, "name" => name),
    )
    return _json(response)["experiment_id"]
end

"""
    create_experiment(client::Client, project_id::Integer, status::ExperimentStatus, name::AbstractString)::Int64

[`ExperimentStatus`](@ref)-typed overload of [`create_experiment`](@ref). The server only accepts
[`IN_PROGRESS`](@ref); the other variants exist for symmetry with the local API.
"""
function create_experiment(
    client::Client, project_id::Integer, status::ExperimentStatus, name::AbstractString
)::Int64
    return create_experiment(client, project_id, (Integer(status)), name)
end

"""
    update_experiment(client::Client, id::Integer; status_id=nothing, name=nothing, description=nothing, end_date=nothing)::Nothing

Patch an [`Experiment`](@ref) via `PATCH /experiment/{id}`. Any keyword left as `nothing`
is left untouched server-side. Reopening (`status_id == Integer(IN_PROGRESS)` on a row
that previously had an `end_date`) clears `end_date` automatically. Requires
[`UpdatePermission`](@ref) on the owning project.
"""
function update_experiment(
    client::Client,
    id::Integer;
    status_id::Optional{Integer}=nothing,
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
    end_date::Optional{DateTime}=nothing,
)::Nothing
    _request(
        client,
        "PATCH",
        "/experiment/$id";
        body=Dict(
            "status_id" => status_id,
            "name" => name,
            "description" => description,
            "end_date" => (isnothing(end_date)) ? nothing : (string(end_date)),
        ),
    )
    return nothing
end

"""
    update_experiment(client::Client, id::Integer, status::ExperimentStatus; name=nothing, description=nothing, end_date=nothing)::Nothing

[`ExperimentStatus`](@ref)-typed overload of [`update_experiment`](@ref).
"""
function update_experiment(
    client::Client,
    id::Integer,
    status::ExperimentStatus;
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
    end_date::Optional{DateTime}=nothing,
)::Nothing
    return update_experiment(
        client,
        id;
        status_id=(Integer(status)),
        name=name,
        description=description,
        end_date=end_date,
    )
end

"""
    delete_experiment(client::Client, id::Integer)::Nothing

Delete an [`Experiment`](@ref) (and its [`Iteration`](@ref)s + [`Resource`](@ref)s) via
`DELETE /experiment/{id}`. Requires [`DeletePermission`](@ref) on the owning project.
"""
function delete_experiment(client::Client, id::Integer)::Nothing
    _request(client, "DELETE", "/experiment/$id")
    return nothing
end
