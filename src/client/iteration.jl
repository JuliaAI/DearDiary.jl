"""
    get_iteration(client::Client, id::Integer)::Optional{Iteration}

Fetch an [`Iteration`](@ref) via `GET /iteration/{id}`. Returns `nothing` when the server
replies 404 and raises [`ClientError`](@ref) for other failures. Requires
[`ReadPermission`](@ref) on the iteration's project.
"""
function get_iteration(client::Client, id::Integer)::Optional{Iteration}
    try
        return _json(_request(client, "GET", "/iteration/$id")) |> Iteration
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

"""
    get_iterations(client::Client, experiment_id::Integer)::Array{Iteration,1}

Convenience wrapper around the paged form: returns the first page (default limit) of
[`Iteration`](@ref) records under `experiment_id` and discards the pagination envelope.
"""
function get_iterations(
    client::Client, experiment_id::Integer,
)::Array{Iteration,1}
    return get_iterations(client, experiment_id, Pagination(50, 0)).data
end

"""
    get_iterations(client::Client, experiment_id::Integer, page::Pagination)::PaginatedResponse{Iteration}

Fetch a page of [`Iteration`](@ref) records under `experiment_id` via
`GET /iteration/experiment/{experiment_id}?limit=…&offset=…`.
"""
function get_iterations(
    client::Client, experiment_id::Integer, page::Pagination,
)::PaginatedResponse{Iteration}
    response = _request(
        client, "GET", "/iteration/experiment/$experiment_id";
        query=Dict("limit" => page.limit, "offset" => page.offset),
    )
    return _paginated(Iteration, _json(response))
end

"""
    create_iteration(client::Client, experiment_id::Integer)::Iteration

Open a fresh [`Iteration`](@ref) under `experiment_id` via
`POST /iteration/experiment/{experiment_id}` and fetch the freshly-created row so the
caller can immediately use its `id` and `created_date`. The parent experiment must be
[`IN_PROGRESS`](@ref). Requires [`CreatePermission`](@ref) on the owning project.
"""
function create_iteration(client::Client, experiment_id::Integer)::Iteration
    response = _request(client, "POST", "/iteration/experiment/$experiment_id")
    iteration_id = _json(response)["iteration_id"]
    return get_iteration(client, iteration_id)
end

"""
    update_iteration(client::Client, id::Integer; notes=nothing, end_date=nothing)::Nothing

Patch an [`Iteration`](@ref) via `PATCH /iteration/{id}`. Any keyword left as `nothing` is
left untouched server-side. Once an iteration has an `end_date` set, the server locks it:
further updates fail with [`ClientError`](@ref) `"INVALID_PAYLOAD"`. Requires
[`UpdatePermission`](@ref) on the owning project.
"""
function update_iteration(
    client::Client, id::Integer;
    notes::Optional{AbstractString}=nothing,
    end_date::Optional{DateTime}=nothing,
)::Nothing
    _request(
        client, "PATCH", "/iteration/$id";
        body=Dict(
            "notes" => notes,
            "end_date" => (end_date |> isnothing) ? nothing : (end_date |> string),
        ),
    )
    return nothing
end

"""
    delete_iteration(client::Client, id::Integer)::Nothing

Delete an [`Iteration`](@ref) (and its [`Parameter`](@ref)s + [`Metric`](@ref)s) via
`DELETE /iteration/{id}`. Requires [`DeletePermission`](@ref) on the owning project.
"""
function delete_iteration(client::Client, id::Integer)::Nothing
    _request(client, "DELETE", "/iteration/$id")
    return nothing
end
