"""
    _request(client, method, path; query, body, multipart)::HTTP.Response

Internal request helper. Adds the bearer token (when set), encodes the body, and translates any
non-2xx response into a [`ClientError`](@ref) carrying the server's stable `code`/`message`.
Successful responses are returned raw so callers can choose how to decode the body (JSON, bytes).
"""
function _request(
    client::Client, method::AbstractString, path::AbstractString;
    query::Optional{AbstractDict}=nothing,
    body=nothing,
    multipart::Optional{HTTP.Form}=nothing,
)::HTTP.Response
    url = client.base_url * path
    if !(query |> isnothing) && !(query |> isempty)
        pairs = ["$(k)=$(v |> string |> HTTP.escapeuri)" for (k, v) in query]
        url = url * "?" * join(pairs, "&")
    end

    headers = Dict{String,String}()
    if !(client.token |> isnothing)
        headers["Authorization"] = "Bearer $(client.token)"
    end

    request_body = if !(multipart |> isnothing)
        multipart
    elseif !(body |> isnothing)
        headers["Content-Type"] = "application/json"
        body |> JSON.json
    else
        ""
    end

    response = HTTP.request(
        method, url;
        headers=headers,
        body=request_body,
        status_exception=false,
    )

    if response.status >= 400
        code, message = "UNKNOWN", "HTTP $(response.status)"
        try
            decoded = JSON.parse(response.body |> String, Dict{String,Any})
            code = get(decoded, "code", code)
            message = get(decoded, "message", message)
        catch
            # Body was empty or not JSON — fall back to the generic message.
        end
        throw(ClientError(response.status, code, message))
    end

    return response
end

"""
    _json(response::HTTP.Response)::Dict{String,Any}

Decode an HTTP response body as JSON into a `Dict{String,Any}`.
"""
_json(response::HTTP.Response)::Dict{String,Any} =
    JSON.parse(response.body |> String, Dict{String,Any})

"""
    _paginated(::Type{T}, dict::AbstractDict)::PaginatedResponse{T}

Build a [`PaginatedResponse`](@ref) for `T` from the standard `{data, total, limit, offset}`
envelope returned by paged list routes.
"""
function _paginated(::Type{T}, dict::AbstractDict)::PaginatedResponse{T} where {T}
    items = (dict["data"] .|> T)::Array{T,1}
    return PaginatedResponse{T}(items, dict["total"], dict["limit"], dict["offset"])
end
