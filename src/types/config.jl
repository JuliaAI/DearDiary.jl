"""
    APIConfig

A struct to hold the configuration for the API server.

# Fields
- `host::String`: The host of the API server.
- `port::Integer`: The port of the API server.
- `db_file::String`: The path to the SQLite database file.
- `jwt_secret::String`: The JWT secret for authentication. If not set, it defaults
    to `Nothing`.
- `enable_auth::Bool`: Whether to enable authentication or not.
- `enable_api::Bool`: Whether the API server is enabled or not.
"""
struct APIConfig
    host::String
    port::Integer
    db_file::String
    jwt_secret::String
    enable_auth::Bool
    enable_api::Bool
end
