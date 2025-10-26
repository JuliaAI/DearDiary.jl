"""
    get_status_by_upsert_result(UpsertResult)::HTTP.StatusCodes

Return the appropriate HTTP status code based on the upsert result.

# Table of conversions
- **Created** -> `HTTP.StatusCodes.CREATED`
- **Updated** -> `HTTP.StatusCodes.OK`
- **Duplicate** -> `HTTP.StatusCodes.CONFLICT`
- **Unprocessable** -> `HTTP.StatusCodes.UNPROCESSABLE_ENTITY`
- **Error** -> `HTTP.StatusCodes.INTERNAL_SERVER_ERROR`
"""
get_status_by_upsert_result(::Created) = HTTP.StatusCodes.CREATED
get_status_by_upsert_result(::Updated) = HTTP.StatusCodes.OK
get_status_by_upsert_result(::Duplicate) = HTTP.StatusCodes.CONFLICT
get_status_by_upsert_result(::Unprocessable) = HTTP.StatusCodes.UNPROCESSABLE_ENTITY
get_status_by_upsert_result(::Error) = HTTP.StatusCodes.INTERNAL_SERVER_ERROR

"""
    Base.String(::Type{<:UpsertResult})::String

Convert an [`UpsertResult`](@ref) type to its string representation in uppercase.

# Arguments
- `::Type{<:UpsertResult}`: The upsert result type to convert

# Returns
A string representation of the upsert result type in uppercase.
"""
Base.String(upsert_result::UpsertResult) =
    upsert_result |> typeof |> nameof |> String |> uppercase

"""
    @admin_required function_name(::HTTP.Request, args...)::HTTP.Response

A macro to enforce that the user making the request has administrative privileges.
"""
macro admin_required(function_definition)
    @assert function_definition.head == :function "The @admin_required macro can only be applied to functions."
    function_signature = function_definition.args[1]
    function_body = function_definition.args[2]

    wrapped_body = quote
        if api_config.enable_auth
            user = request.context[:user]
            if !user.is_admin
                return json(("message" => "Admin privileges required");
                    status=HTTP.StatusCodes.FORBIDDEN)
            end
        else
            @warn "Authentication is disabled. Handlers will be injected with the default admin user."
            user = get_user_by_id(1)
        end
        $(function_body)
    end

    new_function = Expr(:function, function_signature, wrapped_body)
    return esc(new_function)
end

"""
    @same_user_or_admin_required function_name(::HTTP.Request, id::Int,
        args...)::HTTP.Response

A macro to enforce that the user making the request is either an administrator or the owner
of the resource being accessed.
"""
macro same_user_or_admin_required(function_definition)
    @assert function_definition.head == :function "The @owner_or_admin_required macro can only be applied to functions."
    function_signature = function_definition.args[1]
    function_body = function_definition.args[2]

    wrapped_body = quote
        if api_config.enable_auth
            user = request.context[:user]
            if !user.is_admin && user.id != id
                return json(("message" => "Access denied: Admin privileges or resource ownership required");
                    status=HTTP.StatusCodes.FORBIDDEN)
            end
        end
        $(function_body)
    end

    new_function = Expr(:function, function_signature, wrapped_body)
    return esc(new_function)
end
