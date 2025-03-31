"""
    get_user_by_username_handler(request::HTTP.Request, username::String)::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
function get_user_by_username_handler(::HTTP.Request, username::String)::HTTP.Response
    response_user = username |> get_user_by_username

    if (response_user |> isnothing)
        return json(("message" => (HTTP.StatusCodes.NOT_FOUND |> HTTP.statustext));
            status=HTTP.StatusCodes.NOT_FOUND)
    end
    return json(response_user; status=HTTP.StatusCodes.OK)
end

"""
    get_users_handler(request::HTTP.Request)::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
function get_users_handler(::HTTP.Request)::HTTP.Response
    return json(get_users(); status=HTTP.StatusCodes.OK)
end

"""
    create_user_handler(request::HTTP.Request, parameters::Json{UserPayload})::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
function create_user_handler(::HTTP.Request, parameters::Json{UserPayload})::HTTP.Response
    user_payload = parameters.payload
    upsert_result = create_user(user_payload.first_name, user_payload.last_name,
        user_payload.username, user_payload.password)
    upsert_status = upsert_result |> get_status_by_upsert_result
    return json(("message" => upsert_result); status=upsert_status)
end
