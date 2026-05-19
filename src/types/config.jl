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
- `artifact_backend::String`: Which [`AbstractArtifactStore`](@ref) backend handles
  [`Resource`](@ref) bytes. One of `"sqlite"` (default, legacy inline storage),
  `"filesystem"`, or `"s3"`. Selected at server startup by the `DEARDIARY_ARTIFACT_BACKEND`
  env var.
- `artifact_fs_root::String`: Root directory for the [`FilesystemStore`](@ref) backend.
  Honoured only when `artifact_backend == "filesystem"`. Created on first write.
- `artifact_s3_bucket::String`: Bucket name for the [`S3Store`](@ref) backend.
- `artifact_s3_endpoint::String`: Scheme + host for S3 requests
  (e.g. `https://s3.us-east-1.amazonaws.com`, `http://localhost:9000` for MinIO).
- `artifact_s3_region::String`: Region used in the SigV4 credential scope.
- `artifact_s3_access_key::String`, `artifact_s3_secret_key::String`: SigV4 credentials.
"""
struct APIConfig
    host::String
    port::UInt16
    db_file::String
    jwt_secret::String
    enable_auth::Bool
    cors_origins::Vector{String}
    artifact_backend::String
    artifact_fs_root::String
    artifact_s3_bucket::String
    artifact_s3_endpoint::String
    artifact_s3_region::String
    artifact_s3_access_key::String
    artifact_s3_secret_key::String
end
