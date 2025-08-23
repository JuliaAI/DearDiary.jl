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
    create_user_handler(request::HTTP.Request, parameters::Json{UserCreatePayload})::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
function create_user_handler(::HTTP.Request, parameters::Json{UserCreatePayload})::HTTP.Response
    upsert_result = parameters.payload |> create_user
    upsert_status = upsert_result |> get_status_by_upsert_result
    return json(("message" => upsert_result); status=upsert_status)
end

"""
    update_user_handler(request::HTTP.Request, id::Int, parameters::Json{UserUpdatePayload})::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
function update_user_handler(::HTTP.Request, id::Int, parameters::Json{UserUpdatePayload})::HTTP.Response
    upsert_result = update_user(id, parameters.payload)
    upsert_status = upsert_result |> get_status_by_upsert_result
    return json(("message" => upsert_result); status=upsert_status)
end

"""
    delete_user_handler(request::HTTP.Request, id::Int)::HTTP.Response

!!! warning
    This function is for route handling and should not be called directly.
"""
function delete_user_handler(::HTTP.Request, id::Int)::HTTP.Response
    success = id |> delete_user

    if !success
        return json(("message" => (HTTP.StatusCodes.INTERNAL_SERVER_ERROR |> HTTP.statustext));
            status=HTTP.StatusCodes.INTERNAL_SERVER_ERROR)
    end
    return json(("message" => (HTTP.StatusCodes.OK |> HTTP.statustext));
        status=HTTP.StatusCodes.OK)
end
