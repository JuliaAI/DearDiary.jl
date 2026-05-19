"""
    MIGRATION_003_RESOURCE_ARTIFACT_COLUMNS

Forward-only schema migration that prepares the `resource` table for pluggable artifact
storage backends. Adds four columns so a row can describe an artifact stored either inline
(SQLite backend) or in an external store (filesystem, S3).

Columns added:

- `backend TEXT NOT NULL DEFAULT 'sqlite'` — short backend identifier; drives dispatch on the
  [`AbstractArtifactStore`](@ref) trait.
- `uri TEXT DEFAULT ''` — stable pointer at the canonical bytes (e.g. `file:///...`,
  `s3://...`). Empty string for SQLite-backed rows (bytes are inline in `data`).
- `size_bytes INTEGER NOT NULL DEFAULT 0` — exact byte count; lets list endpoints surface the
  artifact size without materialising the BLOB.
- `content_hash TEXT DEFAULT ''` — lower-case sha256 hex digest. Populated for every new
  write; pre-existing rows keep the empty string until [`migrate_artifacts!`](@ref) rehashes
  them.

Pre-existing rows continue to read from `data` exactly as before — every new column has a
default that matches the legacy semantics. The companion change to `services/resource.jl`
routes new inserts through [`current_artifact_store`](@ref).
"""
const MIGRATION_003_RESOURCE_ARTIFACT_COLUMNS = Migration(
    3,
    "resource_artifact_columns",
    [
        "ALTER TABLE resource ADD COLUMN backend TEXT NOT NULL DEFAULT 'sqlite'",
        "ALTER TABLE resource ADD COLUMN uri TEXT DEFAULT ''",
        "ALTER TABLE resource ADD COLUMN size_bytes INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE resource ADD COLUMN content_hash TEXT DEFAULT ''",
    ],
)
