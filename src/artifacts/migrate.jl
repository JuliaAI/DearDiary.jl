"""
    MigrateArtifactsResult

Return value of [`migrate_artifacts!`](@ref).

Fields
- `migrated::Int64`: Number of rows successfully moved off the inline backend.
- `skipped::Int64`: Number of rows that were already on a non-inline backend at scan time
  (typical when a previous pass was interrupted partway through).
- `failed::Int64`: Number of rows where the move could not be completed. Each failure is
  logged via `@error` so the operator can inspect the offending row.
"""
struct MigrateArtifactsResult
    migrated::Int64
    skipped::Int64
    failed::Int64
end

"""
    migrate_artifacts!(target::AbstractArtifactStore = current_artifact_store())::MigrateArtifactsResult

Walk every [`Resource`](@ref) row whose `backend == "inline"`, replay its inline bytes
through `target`, and update the row to point at the new artifact. Use this for one-shot
backfill after switching `DEARDIARY_ARTIFACT_BACKEND` away from `"inline"`:

```julia
using DearDiary
DearDiary.run(; env_file=".env")
DearDiary.migrate_artifacts!()   # uses the now-configured target store
```

The migration is **idempotent and restartable**: rows that have already been migrated have a
different `backend` value and are skipped on subsequent passes. A row that fails (e.g. S3
returns 503) is left untouched, so re-running the function picks up where it stopped.

Refuses to do anything when `target` is itself a [`InlineStore`](@ref): there is nowhere to
move the bytes to.

# Arguments
- `target::AbstractArtifactStore`: Destination store. Defaults to the server's currently
  configured store.

# Returns
A [`MigrateArtifactsResult`](@ref) summarising the pass.
"""
function migrate_artifacts!(
    target::AbstractArtifactStore=current_artifact_store()
)::MigrateArtifactsResult
    if target isa InlineStore
        @warn "migrate_artifacts!: target is InlineStore, nothing to do"
        return MigrateArtifactsResult(0, 0, 0)
    end

    db = get_database()
    rows = DBInterface.execute(
        db, "SELECT id FROM resource WHERE backend = 'inline' ORDER BY id"
    )
    ids = [row.id for row in Tables.namedtupleiterator(rows)]

    target_backend = backend_id(target)
    migrated = 0
    skipped = 0
    failed = 0

    for id in ids
        resource = fetch(Resource, id)
        if (isnothing(resource)) || resource.backend != "inline"
            skipped += 1
            continue
        end

        bytes = (isnothing(resource.data)) ? UInt8[] : (Vector{UInt8}(resource.data))
        try
            write_result = write_artifact(target, bytes)
            # Commit the move in a single UPDATE: flip the backend, point at the new URI,
            # blank out the inline bytes (an empty BLOB), and stamp the metadata columns.
            DBInterface.execute(
                db,
                duckdbify("""
                UPDATE resource
                SET backend = :backend,
                    uri = :uri,
                    size_bytes = :size_bytes,
                    content_hash = :content_hash,
                    data = :data,
                    updated_date = :updated_date
                WHERE id = :id
                """),
                (
                    backend=target_backend,
                    uri=write_result.uri,
                    size_bytes=write_result.size_bytes,
                    content_hash=write_result.content_hash,
                    data=UInt8[],
                    updated_date=(string(now())),
                    id=id,
                ),
            )
            migrated += 1
        catch err
            @error "migrate_artifacts!: failed for resource $(id)" exception=err
            failed += 1
        end
    end

    @info(
        "migrate_artifacts! complete",
        migrated=migrated,
        skipped=skipped,
        failed=failed,
        target=target_backend,
    )
    return MigrateArtifactsResult(migrated, skipped, failed)
end
