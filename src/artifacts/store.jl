"""
    AbstractArtifactStore

Marker abstract supertype for pluggable artifact backends. Concrete subtypes
([`InlineStore`](@ref), [`FilesystemStore`](@ref), [`S3Store`](@ref)) implement
[`write_artifact`](@ref), [`read_artifact`](@ref), and [`delete_artifact`](@ref).

Service code never instantiates a store directly. It calls [`current_artifact_store`](@ref),
which reads the active [`APIConfig`](@ref) and dispatches to the configured backend.
"""
abstract type AbstractArtifactStore end

"""
    ArtifactWriteResult

The metadata returned by [`write_artifact`](@ref). Carries everything a [`Resource`](@ref)
row needs to record the new artifact: the canonical URI, the on-disk size, and the sha256
content hash.

Fields
- `uri::String`: Canonical pointer at the stored bytes. The empty string is the sentinel for
  the inline backend (the bytes live inline in `resource.data`).
- `size_bytes::Int64`: The exact number of bytes written.
- `content_hash::String`: Lower-case sha256 hex digest of the bytes. Always populated; every
  backend hashes on write.
"""
struct ArtifactWriteResult
    uri::String
    size_bytes::Int64
    content_hash::String
end

"""
    backend_id(store::AbstractArtifactStore)::String

Return the short string identifier (`"inline"`, `"filesystem"`, `"s3"`) used to populate
`resource.backend` when a new artifact is written through `store`.
"""
function backend_id end

"""
    write_artifact(store::AbstractArtifactStore, data::AbstractVector{UInt8})::ArtifactWriteResult

Persist `data` through the backend represented by `store` and return the metadata needed to
register the new artifact in the [`Resource`](@ref) table.

For backends that store bytes outside the database (filesystem, S3) this performs the actual
upload. For the [`InlineStore`](@ref) it is a no-op write; the bytes still travel into the
`resource.data` column via the service layer's INSERT.
"""
function write_artifact end

"""
    read_artifact(store::AbstractArtifactStore, uri::AbstractString, inline::Optional{AbstractVector{UInt8}})::Vector{UInt8}

Fetch the bytes for the artifact identified by `uri`, dispatching on `store`.

`inline` is the fallback the caller passes when the canonical bytes live in `resource.data`
rather than in an external store. Backends that store bytes externally ignore `inline`; the
[`InlineStore`](@ref) returns it directly.
"""
function read_artifact end

"""
    delete_artifact(store::AbstractArtifactStore, uri::AbstractString)::Bool

Remove the artifact identified by `uri` from the underlying store. Returns `true` on success.

For the [`InlineStore`](@ref) this is a no-op (the bytes vanish when the parent
[`Resource`](@ref) row is deleted); external backends issue the real delete.
"""
function delete_artifact end

"""
    sha256_hex(data::AbstractVector{UInt8})::String

Compute the lower-case sha256 hex digest of `data`. Used by every backend to populate
[`ArtifactWriteResult`](@ref)`.content_hash`. Delegates to the Julia stdlib `SHA` module, so
the project takes on no extra dependency.
"""
sha256_hex(data::AbstractVector{UInt8})::String = bytes2hex(SHA.sha256(data))

"""
    current_artifact_store()::AbstractArtifactStore

Return the [`AbstractArtifactStore`](@ref) selected by the active [`APIConfig`](@ref).

`run` populates `_DEARDIARY_APICONFIG` at startup, so this helper is only meaningful after
the server has booted (or a test harness has supplied a config). When no config is loaded
the function falls back to [`InlineStore`](@ref) so offline code paths (`@with_deardiary_test_db`)
behave the same as before the artifact-store refactor.
"""
function current_artifact_store()::AbstractArtifactStore
    global _DEARDIARY_APICONFIG
    if isnothing(_DEARDIARY_APICONFIG)
        return InlineStore()
    end
    return artifact_store_for(_DEARDIARY_APICONFIG)
end

"""
    artifact_store_for(config::APIConfig)::AbstractArtifactStore

Return the concrete [`AbstractArtifactStore`](@ref) selected by `config`. Unknown backends
fall back to [`InlineStore`](@ref) with a warning. The server stays bootable, but the
operator gets a loud signal that the env config is wrong.
"""
function artifact_store_for(config::APIConfig)::AbstractArtifactStore
    backend = config.artifact_backend
    if backend == "inline"
        return InlineStore()
    elseif backend == "filesystem"
        return FilesystemStore(config.artifact_fs_root)
    elseif backend == "s3"
        return S3Store(;
            bucket=config.artifact_s3_bucket,
            endpoint=config.artifact_s3_endpoint,
            region=config.artifact_s3_region,
            access_key=config.artifact_s3_access_key,
            secret_key=config.artifact_s3_secret_key,
        )
    end
    @warn "Unknown DEARDIARY_ARTIFACT_BACKEND '$(backend)', falling back to inline"
    return InlineStore()
end

"""
    artifact_store_for(backend::AbstractString)::AbstractArtifactStore

Backend-only convenience: returns [`InlineStore`](@ref) for `"inline"` and warns otherwise.
Useful for tests and tooling that want to dispatch on a backend label without constructing a
full [`APIConfig`](@ref). Backends that need additional config (filesystem root, S3
credentials) must go through the [`APIConfig`](@ref) overload.
"""
function artifact_store_for(backend::AbstractString)::AbstractArtifactStore
    if backend == "inline"
        return InlineStore()
    end
    @warn "artifact_store_for($(backend)) needs an APIConfig, falling back to inline"
    return InlineStore()
end
