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
function Base.String(upsert_result::UpsertResult)::String
    return upsert_result |> typeof |> nameof |> String |> uppercase
end

"""
    AdminRequiredMiddleware(handle::Function)::Function

A middleware function to enforce that the user making the request has administrative privileges.
"""
function AdminRequiredMiddleware(handle::Function)::Function
    function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG
        if _DEARDIARY_APICONFIG.enable_auth
            if !(request.context[:user].is_admin)
                return json(
                    ("message" => "Admin privileges required");
                    status=HTTP.StatusCodes.FORBIDDEN,
                )
            end
        else
            @warn "Authentication is disabled. Handlers will be injected with the default admin user."
            request.context[:user] = get(request.context, :user, get_user("default"))
        end
        return request |> handle
    end
end

"""
    SameUserOrAdminRequiredMiddleware(handle::Function)::Function

A middleware function to enforce that the indicated user is the same user making the request, or that the user has administrative privileges.
"""
function SameUserOrAdminRequiredMiddleware(handle::Function)::Function
    function (request::HTTP.Request)
        global _DEARDIARY_APICONFIG
        if _DEARDIARY_APICONFIG.enable_auth
            user = request.context[:user]
            if !user.is_admin && user.id != (request|>queryparams)[:id]
                return json(
                    ("message" => "Same user required");
                    status=HTTP.StatusCodes.FORBIDDEN,
                )
            end
        else
            @warn "Authentication is disabled. Handlers will be injected with the default admin user."
            request.context[:user] = get(request.context, :user, get_user("default"))
        end
        return request |> handle
    end
end

"""
    find(form_data::AbstractArray{HTTP.Multipart,1}, field_name::AbstractString)::Union{HTTP.Multipart,Nothing}

Find a part in the multipart form data by its field name.

# Arguments
- `form_data::AbstractArray{HTTP.Multipart,1}`: The multipart form data to search.
- `field_name::AbstractString`: The name of the field to find.

# Returns
An `HTTP.Multipart` part if found, otherwise `nothing`.
"""
function find(
    form_data::AbstractArray{HTTP.Multipart,1}, field_name::AbstractString,
)::Union{HTTP.Multipart,Nothing}
    index = findfirst(part -> part.name == field_name, form_data)
    return index |> isnothing ? nothing : form_data[index]
end
