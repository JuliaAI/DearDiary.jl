"""
    InlineStore <: AbstractArtifactStore

The default artifact backend: bytes live inline in the `resource.data` column of the project
database. There is no separate write to disk or object store; the bytes travel into the
database as part of the same INSERT that creates the [`Resource`](@ref) row.

This is the default for offline tests and for installations that have not opted into the
external backends. It is also the only backend that does not require any out-of-band setup
(filesystem root, S3 credentials).
"""
struct InlineStore <: AbstractArtifactStore end

backend_id(::InlineStore)::String = "inline"

"""
    write_artifact(::InlineStore, data)::ArtifactWriteResult

For the inline backend the bytes are still inserted in-line into `resource.data` by the
service layer. This method only computes the metadata the caller needs to populate the new
columns (`size_bytes`, `content_hash`) on the resource row. The `uri` field is returned as
the empty string, the sentinel that signals "look at `resource.data`, not at an external
URL".
"""
function write_artifact(::InlineStore, data::AbstractVector{UInt8})::ArtifactWriteResult
    return ArtifactWriteResult("", (length(data)), sha256_hex(data))
end

"""
    read_artifact(::InlineStore, uri, inline)::Vector{UInt8}

`uri` is ignored; the inline backend has no external storage to dereference. `inline` is
the bytes from `resource.data`, which the service layer fetches alongside the rest of the
row. The method is provided for trait completeness so service code can call
`read_artifact(store, ref.uri, row.data)` uniformly across backends.
"""
function read_artifact(
    ::InlineStore, ::AbstractString, inline::Optional{<:AbstractVector{UInt8}}
)::Vector{UInt8}
    if isnothing(inline)
        throw(ArgumentError("InlineStore.read_artifact requires inline bytes"))
    end
    return Vector{UInt8}(inline)
end

"""
    delete_artifact(::InlineStore, uri)::Bool

No-op for the inline backend: the bytes vanish with the parent `resource` row when the
caller runs `DELETE FROM resource`. Returns `true` so the service layer's bookkeeping does
not have to special-case the backend.
"""
delete_artifact(::InlineStore, ::AbstractString)::Bool = true
