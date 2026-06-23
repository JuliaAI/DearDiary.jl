"""
    error_code(::Type{<:ErrorCode})::String

Return the stable SCREAMING_SNAKE identifier for an [`ErrorCode`](@ref) type, as used
in error response bodies (`{"code": ..., "message": ...}`). The mapping is fixed so
frontend code can switch on the value without parsing English messages.
"""
error_code(::Type{NotFound})::String = "NOT_FOUND"
error_code(::Type{InvalidCredentials})::String = "INVALID_CREDENTIALS"
error_code(::Type{TokenMissing})::String = "TOKEN_MISSING"
error_code(::Type{TokenInvalid})::String = "TOKEN_INVALID"
error_code(::Type{TokenExpired})::String = "TOKEN_EXPIRED"
error_code(::Type{TokenPayloadInvalid})::String = "TOKEN_PAYLOAD_INVALID"
error_code(::Type{UserNotFound})::String = "USER_NOT_FOUND"
error_code(::Type{AdminRequired})::String = "ADMIN_REQUIRED"
error_code(::Type{SameUserRequired})::String = "SAME_USER_REQUIRED"
error_code(::Type{ProjectPermissionRequired})::String = "PROJECT_PERMISSION_REQUIRED"
error_code(::Type{Conflict})::String = "CONFLICT"
error_code(::Type{InvalidPayload})::String = "INVALID_PAYLOAD"
error_code(::Type{ServerError})::String = "SERVER_ERROR"

"""
    error_response(::Type{<:ErrorCode}, message::AbstractString; status)::HTTP.Response

Build an error response with the standard `{"code": ..., "message": ...}` envelope.

# Arguments
- `::Type{<:ErrorCode}`: The stable identifier as a type tag (see [`error_code`](@ref)).
- `message::AbstractString`: A human-readable description for logs and (optionally) UI fallback.
- `status`: HTTP status code (passed through to [`Oxygen.json`](@extref Oxygen.Json.json)).

# Returns
An HTTP response with JSON body and the given status.
"""
function error_response(::Type{C}, message::AbstractString; status) where {C<:ErrorCode}
    return json(
        Dict("code" => error_code(C), "message" => (string(message))); status=status
    )
end

"""
    upsert_to_error_code(result::UpsertResult)::Type{<:ErrorCode}

Map a non-success [`UpsertResult`](@ref) to the matching [`ErrorCode`](@ref) type so
write-outcome failures surface a stable code in the response body.

Passing a successful result ([`Created`](@ref) or [`Updated`](@ref)) is a programmer
error; the function falls through to [`ServerError`](@ref).
"""
upsert_to_error_code(::Type{Duplicate})::Type{<:ErrorCode} = Conflict
upsert_to_error_code(::Type{Unprocessable})::Type{<:ErrorCode} = InvalidPayload
upsert_to_error_code(::Type{Error})::Type{<:ErrorCode} = ServerError
upsert_to_error_code(::Type{<:UpsertResult})::Type{<:ErrorCode} = ServerError

"""
    get_status_by_upsert_result(UpsertResult)::HTTP.StatusCodes

Return the HTTP status code for a given [`UpsertResult`](@ref).

- `Created` → `HTTP.StatusCodes.CREATED`
- `Updated` → `HTTP.StatusCodes.OK`
- `Duplicate` → `HTTP.StatusCodes.CONFLICT`
- `Unprocessable` → `HTTP.StatusCodes.UNPROCESSABLE_ENTITY`
- `Error` → `HTTP.StatusCodes.INTERNAL_SERVER_ERROR`
"""
get_status_by_upsert_result(::Type{Created}) = HTTP.StatusCodes.CREATED
get_status_by_upsert_result(::Type{Updated}) = HTTP.StatusCodes.OK
get_status_by_upsert_result(::Type{Duplicate}) = HTTP.StatusCodes.CONFLICT
get_status_by_upsert_result(::Type{Unprocessable}) = HTTP.StatusCodes.UNPROCESSABLE_ENTITY
get_status_by_upsert_result(::Type{Error}) = HTTP.StatusCodes.INTERNAL_SERVER_ERROR

"""
    Base.String(::Type{<:UpsertResult})::String

Return the uppercase string name of an [`UpsertResult`](@ref) type.
"""
function Base.String(::Type{T})::String where {T<:UpsertResult}
    return uppercase(String(nameof(T)))
end

"""
    AdminRequiredMiddleware(handle::Function)::Function

Middleware that rejects requests from non-admin users with `403 ADMIN_REQUIRED`.
"""
function AdminRequiredMiddleware(handle::Function)::Function
    function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG
        if _DEARDIARY_APICONFIG.enable_auth
            if !(request.context[:user].is_admin)
                return error_response(
                    AdminRequired,
                    "Admin privileges required";
                    status=HTTP.StatusCodes.FORBIDDEN,
                )
            end
        else
            @warn "Authentication is disabled. Handlers will be injected with the default admin user."
            request.context[:user] = get(request.context, :user, get_user("default"))
        end
        return handle(request)
    end
end

"""
    SameUserOrAdminRequiredMiddleware(handle::Function)::Function

Middleware that passes only when the authenticated user matches the target id or is an admin.

Reads the target user id from the URL path (`/user/{id}`) using [`path_segments`](@ref),
because Oxygen binds `request.context[:params]` only when the registered handler runs,
after route-level middleware.
"""
function SameUserOrAdminRequiredMiddleware(handle::Function)::Function
    function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG
        if _DEARDIARY_APICONFIG.enable_auth
            user = request.context[:user]
            if !user.is_admin
                segments = path_segments(request)
                target_id =
                    (length(segments)) >= 2 ? tryparse(Int64, segments[2]) : nothing
                if isnothing(target_id)
                    return error_response(
                        NotFound,
                        (HTTP.statustext(HTTP.StatusCodes.NOT_FOUND));
                        status=HTTP.StatusCodes.NOT_FOUND,
                    )
                end
                if user.id != target_id
                    return error_response(
                        SameUserRequired,
                        "Same user required";
                        status=HTTP.StatusCodes.FORBIDDEN,
                    )
                end
            end
        else
            @warn "Authentication is disabled. Handlers will be injected with the default admin user."
            request.context[:user] = get(request.context, :user, get_user("default"))
        end
        return handle(request)
    end
end

"""
    parse_pagination(request::HTTP.Request; default_limit::Integer=50, max_limit::Integer=200)::Pagination

Read `?limit=` and `?offset=` from the request's query string and produce a [`Pagination`](@ref).

Missing parameters fall back to the defaults; non-integer or negative values are clamped to the
nearest valid bound. `limit` is capped at `max_limit` so a client can't request unbounded pages.

# Arguments
- `request::HTTP.Request`: The incoming request.
- `default_limit::Integer`: Default page size when `?limit=` is not provided.
- `max_limit::Integer`: Hard cap on the requested page size.

# Returns
A [`Pagination`](@ref) bounded to non-negative offset and `[0, max_limit]` limit.
"""
function parse_pagination(
    request::HTTP.Request; default_limit::Integer=50, max_limit::Integer=200
)::Pagination
    qp = queryparams(request)
    limit = if haskey(qp, "limit")
        parsed = tryparse(Int64, qp["limit"])
        isnothing(parsed) ? default_limit : min(max(0, parsed), max_limit)
    else
        default_limit
    end
    offset = if haskey(qp, "offset")
        parsed = tryparse(Int64, qp["offset"])
        isnothing(parsed) ? 0 : max(0, parsed)
    else
        0
    end
    return Pagination(limit, offset)
end

"""
    path_segments(request::HTTP.Request)::Vector{String}

Return the URL path segments of `request`, stripped of any query string.

Route-specific middleware runs before Oxygen binds path params to `request.context`, so
`HTTP.getparams` is not yet populated. Parsing `request.target` directly keeps this
middleware decoupled from Oxygen's request lifecycle.

# Arguments
- `request::HTTP.Request`: The incoming HTTP request.

# Returns
The non-empty `/`-separated segments of the request path.
"""
function path_segments(request::HTTP.Request)::Vector{String}
    target = request.target
    query_index = findfirst('?', target)
    path_only = (isnothing(query_index)) ? target : target[1:(query_index - 1)]
    return string.(split(path_only, '/'; keepempty=false))
end

"""
    get_project_id(::Type{T}, request::HTTP.Request)::Optional{Int64} where {T}

Resolve the [`Project`](@ref) id that scopes a request to entity type `T`. Each method matches
the URL pattern of the route family (`/experiment/...`, `/iteration/...`, etc.) and walks the
entity hierarchy via the service-layer [`get_project_id`](@ref) overloads.

# Arguments
- `::Type{T}`: The entity type the route operates on (`Experiment`, `Iteration`, `Metric`,
  `Parameter`, or `Resource`).
- `request::HTTP.Request`: The incoming HTTP request.

# Returns
The owning project id, or `nothing` if it cannot be resolved (URL does not match a known
pattern, malformed id, or an ancestor record that no longer exists).
"""
function get_project_id(::Type{Project}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    (length(segments)) >= 2 || return nothing
    return tryparse(Int64, segments[2])
end

function get_project_id(::Type{Experiment}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    n = length(segments)
    n >= 3 && segments[2] == "project" && return tryparse(Int64, segments[3])
    n >= 2 || return nothing

    experiment_id = tryparse(Int64, segments[2])
    isnothing(experiment_id) && return nothing
    experiment = get_experiment(experiment_id)
    return isnothing(experiment) ? nothing : (get_project_id(experiment))
end

function get_project_id(::Type{Iteration}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    n = length(segments)
    if n >= 3 && segments[2] == "experiment"
        experiment_id = tryparse(Int64, segments[3])
        isnothing(experiment_id) && return nothing
        experiment = get_experiment(experiment_id)
        return isnothing(experiment) ? nothing : (get_project_id(experiment))
    end
    n >= 2 || return nothing

    iteration_id = tryparse(Int64, segments[2])
    isnothing(iteration_id) && return nothing
    iteration = get_iteration(iteration_id)
    return isnothing(iteration) ? nothing : (get_project_id(iteration))
end

function get_project_id(::Type{Metric}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    n = length(segments)
    if n >= 3 && segments[2] == "iteration"
        iteration_id = tryparse(Int64, segments[3])
        isnothing(iteration_id) && return nothing
        iteration = get_iteration(iteration_id)
        return isnothing(iteration) ? nothing : (get_project_id(iteration))
    end
    n >= 2 || return nothing

    metric_id = tryparse(Int64, segments[2])
    isnothing(metric_id) && return nothing
    metric = get_metric(metric_id)
    return isnothing(metric) ? nothing : (get_project_id(metric))
end

function get_project_id(::Type{Parameter}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    n = length(segments)
    if n >= 3 && segments[2] == "iteration"
        iteration_id = tryparse(Int64, segments[3])
        isnothing(iteration_id) && return nothing
        iteration = get_iteration(iteration_id)
        return isnothing(iteration) ? nothing : (get_project_id(iteration))
    end
    n >= 2 || return nothing

    parameter_id = tryparse(Int64, segments[2])
    isnothing(parameter_id) && return nothing
    parameter = get_parameter(parameter_id)
    return isnothing(parameter) ? nothing : (get_project_id(parameter))
end

function get_project_id(::Type{Resource}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    n = length(segments)
    if n >= 3 && segments[2] == "experiment"
        experiment_id = tryparse(Int64, segments[3])
        isnothing(experiment_id) && return nothing
        experiment = get_experiment(experiment_id)
        return isnothing(experiment) ? nothing : (get_project_id(experiment))
    end
    n >= 2 || return nothing

    resource_id = tryparse(Int64, segments[2])
    isnothing(resource_id) && return nothing
    resource = get_resource(resource_id)
    return isnothing(resource) ? nothing : (get_project_id(resource))
end

function get_project_id(::Type{Model}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    n = length(segments)
    n >= 3 && segments[2] == "project" && return tryparse(Int64, segments[3])
    n >= 2 || return nothing

    model_id = tryparse(Int64, segments[2])
    isnothing(model_id) && return nothing
    model = get_model(model_id)
    return isnothing(model) ? nothing : (get_project_id(model))
end

function get_project_id(::Type{ModelVersion}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    n = length(segments)
    if n >= 3 && segments[2] == "model"
        model_id = tryparse(Int64, segments[3])
        isnothing(model_id) && return nothing
        model = get_model(model_id)
        return isnothing(model) ? nothing : (get_project_id(model))
    end
    n >= 2 || return nothing

    version_id = tryparse(Int64, segments[2])
    isnothing(version_id) && return nothing
    version = get_modelversion(version_id)
    return isnothing(version) ? nothing : (get_project_id(version))
end

function get_project_id(::Type{Tag}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    (length(segments)) >= 3 || return nothing

    parent_kind = segments[2]
    parent_id = tryparse(Int64, segments[3])
    isnothing(parent_id) && return nothing

    parent_kind == "project" && return parent_id
    if parent_kind == "experiment"
        experiment = get_experiment(parent_id)
        return isnothing(experiment) ? nothing : (get_project_id(experiment))
    end
    if parent_kind == "iteration"
        iteration = get_iteration(parent_id)
        return isnothing(iteration) ? nothing : (get_project_id(iteration))
    end
    return nothing
end

function get_project_id(::Type{UserPermission}, request::HTTP.Request)::Optional{Int64}
    segments = path_segments(request)
    (length(segments)) >= 2 || return nothing
    segments[1] == "project" || return nothing
    return tryparse(Int64, segments[2])
end

"""
    ProjectPermissionRequiredMiddleware(::Type{T}, ::Type{A})::Function where {T, A<:PermissionAction}

Return a middleware that enforces a [`PermissionAction`](@ref) against the [`UserPermission`](@ref)
row tying the current user to the [`Project`](@ref) owning an entity of type `T`.

`T` drives [`get_project_id`](@ref) via multiple dispatch to walk path params and the entity
hierarchy. `A` drives [`has_permission`](@ref) via multiple dispatch to check the matching
boolean field on `UserPermission`.

Admins bypass the check. When auth is disabled, the default admin user is injected, matching
the fallback used by [`AdminRequiredMiddleware`](@ref).

# Arguments
- `::Type{T}`: The entity type the route operates on.
- `::Type{A}`: The required CRUD action, passed as a type tag
  (`CreatePermission`, `ReadPermission`, `UpdatePermission`, `DeletePermission`).

# Returns
A middleware with signature `(handle::Function) -> (HTTP.Request) -> response`.
"""
function ProjectPermissionRequiredMiddleware(
    ::Type{T}, ::Type{A}
)::Function where {T,A<:PermissionAction}
    function (handle::Function)
        function (request::HTTP.Request)
            global _DEARDIARY_APICONFIG
            if _DEARDIARY_APICONFIG.enable_auth
                user = request.context[:user]
                if !user.is_admin
                    project_id = get_project_id(T, request)
                    if isnothing(project_id)
                        return error_response(
                            NotFound,
                            (HTTP.statustext(HTTP.StatusCodes.NOT_FOUND));
                            status=HTTP.StatusCodes.NOT_FOUND,
                        )
                    end

                    permission = get_userpermission(user.id, project_id)
                    if (isnothing(permission)) || !has_permission(permission, A)
                        return error_response(
                            ProjectPermissionRequired,
                            "Project permission required";
                            status=HTTP.StatusCodes.FORBIDDEN,
                        )
                    end
                end
            else
                @warn "Authentication is disabled. Handlers will be injected with the default admin user."
                request.context[:user] = get(request.context, :user, get_user("default"))
            end
            return handle(request)
        end
    end
end

"""
    find(form_data::AbstractArray{HTTP.Multipart,1}, field_name::AbstractString)::Union{HTTP.Multipart,Nothing}

Return the first part in `form_data` whose name equals `field_name`, or `nothing` if absent.
"""
function find(
    form_data::AbstractArray{HTTP.Multipart,1}, field_name::AbstractString
)::Union{HTTP.Multipart,Nothing}
    index = findfirst(part -> part.name == field_name, form_data)
    return isnothing(index) ? nothing : form_data[index]
end
