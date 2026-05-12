"""
    get_tag(client::Client, id::Integer)::Optional{Tag}

Fetch a [`Tag`](@ref) by id via `GET /tag/{id}`. Returns `nothing` when the server replies
404 and raises [`ClientError`](@ref) for other failures. Admin-only route.

The value-based local overload (`get_tag(value)`) has no REST counterpart; iterate the
parent-scoped [`get_tags`](@ref) listings to discover a tag by its value.
"""
function get_tag(client::Client, id::Integer)::Optional{Tag}
    try
        return _json(_request(client, "GET", "/tag/$id")) |> Tag
    catch err
        err isa ClientError && err.status == 404 && return nothing
        rethrow(err)
    end
end

# Map an entity type to the URL segment the tag routes expect.
_tag_segment(::Type{Project}) = "project"
_tag_segment(::Type{Experiment}) = "experiment"
_tag_segment(::Type{Iteration}) = "iteration"

"""
    get_tags(client::Client, ::Type{T}, parent_id::Integer)::Array{Tag,1} where {T<:Union{Project,Experiment,Iteration}}

List every [`Tag`](@ref) attached to `parent_id` of kind `T`, via
`GET /tag/{kind}/{parent_id}`. Requires [`ReadPermission`](@ref) on the owning project.
"""
function get_tags(
    client::Client, ::Type{T}, parent_id::Integer,
)::Array{Tag,1} where {T<:Union{Project,Experiment,Iteration}}
    response = _request(client, "GET", "/tag/$(_tag_segment(T))/$parent_id")
    decoded = JSON.parse(response.body |> String)
    return [item |> Tag for item in decoded]
end

"""
    add_tag(client::Client, ::Type{T}, parent_id::Integer, value::AbstractString)::Int64 where {T<:Union{Project,Experiment,Iteration}}

Attach a tag `value` to `parent_id` of kind `T`, via `POST /tag/{kind}/{parent_id}`. The
server upserts the underlying [`Tag`](@ref) row if it does not exist already. Returns the
association id. Requires [`CreatePermission`](@ref) on the owning project; for iterations
the parent must not be terminated.

The local standalone `create_tag(value)` has no REST counterpart — tags only exist
attached to a parent.
"""
function add_tag(
    client::Client, ::Type{T}, parent_id::Integer, value::AbstractString,
)::Int64 where {T<:Union{Project,Experiment,Iteration}}
    response = _request(
        client, "POST", "/tag/$(_tag_segment(T))/$parent_id";
        body=Dict("value" => value),
    )
    return _json(response)["association_id"]
end

"""
    delete_tag(client::Client, id::Integer)::Nothing

Delete a [`Tag`](@ref) (and its parent associations) via `DELETE /tag/{id}`. Admin-only.
"""
function delete_tag(client::Client, id::Integer)::Nothing
    _request(client, "DELETE", "/tag/$id")
    return nothing
end
