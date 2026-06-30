"""
    Resource <: ResultType

A struct representing a resource associated with an experiment.

Fields
- `id::String`: The ID of the resource.
- `experiment_id::String`: The ID of the experiment this resource belongs to.
- `name::String`: The name of the resource.
- `description::String`: A description of the resource.
- `data::Optional{Array{UInt8,1}}`: The binary data of the resource. Populated for the
  inline backend (legacy inline storage); `nothing` for rows whose canonical bytes live in
  an external backend (filesystem, S3) and are fetched on demand via the trait.
- `created_date::DateTime`: The date and time when the resource was created.
- `updated_date::Optional{DateTime}`: The date and time when the resource was last updated.
- `backend::String`: Short backend identifier (`"inline"`, `"filesystem"`, `"s3"`). Drives
  dispatch on the [`AbstractArtifactStore`](@ref) trait.
- `uri::String`: Stable pointer at the canonical bytes (`"file:///..."`, `"s3://..."`).
  Empty string when `backend == "inline"` (the bytes are inline in `data`).
- `size_bytes::Int64`: Exact byte count of the artifact. Surfaced in list endpoints without
  materialising the BLOB.
- `content_hash::String`: Lower-case sha256 hex digest of the bytes. Empty string for
  legacy rows not yet re-hashed by the backfill pass.
"""
struct Resource <: ResultType
    id::String
    experiment_id::String
    name::String
    description::String
    data::Optional{Array{UInt8,1}}
    created_date::DateTime
    updated_date::Optional{DateTime}
    backend::String
    uri::String
    size_bytes::Int64
    content_hash::String
end

# JSON.lower hook: omit the raw `data` bytes from any response that serializes a Resource.
# Clients fetch the body via the dedicated `GET /resource/{id}/data` route.
function JSON.lower(resource::Resource)::Dict{String,Any}
    return Dict{String,Any}(
        "id" => resource.id,
        "experiment_id" => resource.experiment_id,
        "name" => resource.name,
        "description" => resource.description,
        "created_date" => resource.created_date,
        "updated_date" => resource.updated_date,
        "backend" => resource.backend,
        "uri" => resource.uri,
        "size_bytes" => resource.size_bytes,
        "content_hash" => resource.content_hash,
    )
end
