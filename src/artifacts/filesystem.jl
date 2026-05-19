"""
    FilesystemStore <: AbstractArtifactStore

Filesystem-backed artifact store. Writes each artifact to a fresh file under
`<root>/<aa>/<uuid>`, where `<aa>` is a two-character shard derived from the UUID (so a
single directory never grows unbounded). The bytes never enter the SQLite database — the
[`Resource`](@ref) row holds only metadata (size, sha256, the `file://` URI).

Fields
- `root::String`: Absolute directory under which every artifact lives.

Selected at server startup by `DEARDIARY_ARTIFACT_BACKEND=filesystem` with the root supplied
through `DEARDIARY_ARTIFACT_FS_ROOT`. The directory is created on first write.
"""
struct FilesystemStore <: AbstractArtifactStore
    root::String
end

backend_id(::FilesystemStore)::String = "filesystem"

const FILE_URI_PREFIX = "file://"

"""
    write_artifact(store::FilesystemStore, data)::ArtifactWriteResult

Allocate a fresh random UUID, write `data` to `<root>/<uuid[1:2]>/<uuid>`, and return a
`file://`-prefixed absolute path. The shard directory is created if missing.

Each call produces a distinct path — there is no content-addressed dedupe at the filesystem
level, so deleting one [`Resource`](@ref) can never break another that happened to upload
identical bytes.
"""
function write_artifact(
    store::FilesystemStore, data::AbstractVector{UInt8},
)::ArtifactWriteResult
    id = UUIDs.uuid4() |> string
    shard = id[1:2]
    shard_dir = joinpath(store.root, shard)
    mkpath(shard_dir)

    path = joinpath(shard_dir, id)
    open(path, "w") do io
        write(io, data)
    end

    uri = FILE_URI_PREFIX * path
    return ArtifactWriteResult(uri, (data |> length), data |> sha256_hex)
end

"""
    read_artifact(store::FilesystemStore, uri, inline)::Vector{UInt8}

Resolve `uri` to a local path and return the file's contents. `inline` is ignored — for
this backend the canonical bytes live on disk. Raises an [`ArgumentError`](@ref) if `uri`
does not start with the `file://` prefix.
"""
function read_artifact(
    ::FilesystemStore,
    uri::AbstractString,
    ::Optional{<:AbstractVector{UInt8}},
)::Vector{UInt8}
    return uri |> _path_from_uri |> read
end

"""
    delete_artifact(::FilesystemStore, uri)::Bool

Remove the file at `uri`. Returns `true` whether or not the file existed — a missing file is
treated as already deleted so callers can run idempotently.
"""
function delete_artifact(::FilesystemStore, uri::AbstractString)::Bool
    path = uri |> _path_from_uri
    if path |> isfile
        rm(path; force=true)
    end
    return true
end

function _path_from_uri(uri::AbstractString)::String
    if !startswith(uri, FILE_URI_PREFIX)
        throw(ArgumentError("FilesystemStore expects '$FILE_URI_PREFIX' URIs, got '$uri'"))
    end
    return uri[(FILE_URI_PREFIX |> length) + 1:end]
end
