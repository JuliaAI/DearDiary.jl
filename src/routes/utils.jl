"""
    get_status_by_upsert_result(upsert_result::UpsertResult)::HTTP.StatusCodes

Return the appropriate HTTP status code based on the upsert result.

# Table of conversions
- **CREATED**: `HTTP.StatusCodes.CREATED`
- **UPDATED**: `HTTP.StatusCodes.OK`
- **DUPLICATE**: `HTTP.StatusCodes.CONFLICT`
- **ERROR**: `HTTP.StatusCodes.INTERNAL_SERVER_ERROR`
"""
function get_status_by_upsert_result(upsert_result::UpsertResult)::Integer
    if upsert_result == CREATED
        return HTTP.StatusCodes.CREATED
    elseif upsert_result == UPDATED
        return HTTP.StatusCodes.OK
    elseif upsert_result == DUPLICATE
        return HTTP.StatusCodes.CONFLICT
    elseif upsert_result == UNPROCESSABLE
        return HTTP.StatusCodes.UNPROCESSABLE_ENTITY
    else
        return HTTP.StatusCodes.INTERNAL_SERVER_ERROR
    end
end
