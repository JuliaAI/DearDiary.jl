# Storage

DearDiary uses two storage layers: a metadata database and an artifact backend. They are
configured independently, so a local database can be paired with remote artifact storage.

## Metadata: DuckDB

All entity records (projects, experiments, iterations, parameters, metrics, model versions)
live in a single [DuckDB](https://duckdb.org) file. The path defaults to `deardiary.db` in
the working directory and is overridden by the `DEARDIARY_DB_FILE` environment variable.

The database is created and migrated automatically on first use. There is nothing to
provision: copying the file is sufficient to move or back up the full tracking history.
Schema changes ship as forward-only migrations that run when the file is opened; see
[Migrations](@ref).

DuckDB replaced an earlier SQLite store. It cannot open the files that store produced, so
start from a fresh database file.

## Artifacts: pluggable backends

Artifact bytes (model files, plots, data exports) flow through an
[`AbstractArtifactStore`](@ref DearDiary.AbstractArtifactStore) backend. Three backends are available:

| Backend | `DEARDIARY_ARTIFACT_BACKEND` value | Where bytes live |
|---|---|---|
| Inline (default) | `inline` | BLOB column in the DuckDB database |
| Filesystem | `filesystem` | Local directory (`DEARDIARY_ARTIFACT_FS_ROOT`) |
| S3 | `s3` | Object storage bucket (`DEARDIARY_ARTIFACT_S3_BUCKET`) |

The backend is selected at server startup from the `DEARDIARY_ARTIFACT_BACKEND` environment
variable. The default is `inline`, which requires no additional configuration: bytes are
stored directly in the `resource.data` column alongside the rest of the metadata. For large
or numerous artifacts, `filesystem` or `s3` keeps the database file small.

The concrete backend types are [`InlineStore`](@ref DearDiary.InlineStore), [`FilesystemStore`](@ref DearDiary.FilesystemStore), and
[`S3Store`](@ref DearDiary.S3Store). Service code calls [`current_artifact_store`](@ref DearDiary.current_artifact_store) to get the active
store without knowing which backend is configured.

Each [`Resource`](@ref DearDiary.Resource) row records the backend that holds its bytes (the `backend` field)
and a canonical URI (`uri`). The inline backend leaves `uri` empty; external backends set
it to a `file:///...` or `s3://...` path.

## Migrating between backends

[`migrate_artifacts!`](@ref) moves existing inline artifacts to the currently configured
external backend. Run it once after switching `DEARDIARY_ARTIFACT_BACKEND` away from
`inline`:

```julia
using DearDiary
DearDiary.run(; env_file=".env")
DearDiary.migrate_artifacts!()
```

The pass is idempotent: already-migrated rows are skipped, and rows that fail are left
untouched so a re-run picks up where it stopped.

For the full walkthrough see [Migrate artifacts between backends](@ref).
