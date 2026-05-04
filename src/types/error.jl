"""
    ErrorCode

Marker abstract type for error codes returned in non-2xx response bodies.

Concrete subtypes pair with [`error_code`](@ref) to produce a stable, frontend-facing
identifier (e.g., `"NOT_FOUND"`, `"PROJECT_PERMISSION_REQUIRED"`) that callers can switch on
without parsing English messages.
"""
abstract type ErrorCode end

"""
    NotFound <: ErrorCode

The requested entity does not exist. Pairs with HTTP `404 Not Found`.
"""
struct NotFound <: ErrorCode end

"""
    InvalidCredentials <: ErrorCode

The supplied username/password did not authenticate. Pairs with HTTP `401 Unauthorized`.
"""
struct InvalidCredentials <: ErrorCode end

"""
    TokenMissing <: ErrorCode

The request did not include an `Authorization` header. Pairs with HTTP `401 Unauthorized`.
"""
struct TokenMissing <: ErrorCode end

"""
    TokenInvalid <: ErrorCode

The bearer token failed signature validation. Pairs with HTTP `401 Unauthorized`.
"""
struct TokenInvalid <: ErrorCode end

"""
    TokenExpired <: ErrorCode

The bearer token's `exp` claim is in the past. Pairs with HTTP `401 Unauthorized`.
"""
struct TokenExpired <: ErrorCode end

"""
    TokenPayloadInvalid <: ErrorCode

The bearer token decoded but its claims are missing or malformed. Pairs with HTTP `401`.
"""
struct TokenPayloadInvalid <: ErrorCode end

"""
    UserNotFound <: ErrorCode

The user identified by the credentials or token does not exist. Pairs with HTTP `401`/`404`
depending on context.
"""
struct UserNotFound <: ErrorCode end

"""
    AdminRequired <: ErrorCode

The route requires administrative privileges. Pairs with HTTP `403 Forbidden`.
"""
struct AdminRequired <: ErrorCode end

"""
    SameUserRequired <: ErrorCode

The route can only be accessed by the targeted user (or an admin). Pairs with HTTP `403`.
"""
struct SameUserRequired <: ErrorCode end

"""
    ProjectPermissionRequired <: ErrorCode

The user lacks the required CRUD permission on the project that scopes the route. Pairs with
HTTP `403 Forbidden`.
"""
struct ProjectPermissionRequired <: ErrorCode end

"""
    Conflict <: ErrorCode

A unique-constraint violation: the resource already exists. Pairs with HTTP `409 Conflict`.
"""
struct Conflict <: ErrorCode end

"""
    InvalidPayload <: ErrorCode

The request payload violates a constraint (foreign key, check, missing field). Pairs with
HTTP `422 Unprocessable Entity`.
"""
struct InvalidPayload <: ErrorCode end

"""
    ServerError <: ErrorCode

Generic catch-all for unexpected failures. Pairs with HTTP `500 Internal Server Error`.
"""
struct ServerError <: ErrorCode end
