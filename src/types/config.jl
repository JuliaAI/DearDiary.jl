"""
    APIConfig

A struct to hold the configuration for the API server.

Fields
- `host`: The host of the API server.
- `port`: The port of the API server.
- `db_file`: The path to the SQLite database file.
- `jwt_secret`: The JWT secret for authentication.
- `enable_auth`: Whether to enable authentication or not.
- `enable_api`: Whether the API server is enabled or not.
"""
struct APIConfig
    host::String
    port::Integer
    db_file::String
    jwt_secret::String
    enable_auth::Bool
    enable_api::Bool
end
