"""
    APIConfig

A struct to hold the configuration for the API server.

Fields
- `host::String`: The host of the API server.
- `port::UInt16`: The port of the API server.
- `db_file::String`: The path to the SQLite database file.
- `jwt_secret::String`: The JWT secret for authentication.
- `enable_auth::Bool`: Whether to enable authentication or not.
- `cors_origins::Vector{String}`: Browser origins allowed to call the API. Use `["*"]`
  to allow any origin (default in development).
"""
struct APIConfig
    host::String
    port::UInt16
    db_file::String
    jwt_secret::String
    enable_auth::Bool
    cors_origins::Vector{String}
end
