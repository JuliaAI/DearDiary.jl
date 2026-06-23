# Migrate artifacts between backends

[`migrate_artifacts!`](@ref) moves a project's inline artifact bytes to the configured
external backend (filesystem or S3). Run it once after switching
`DEARDIARY_ARTIFACT_BACKEND` away from `inline`.

The following shows the call shape (requires a populated project and a configured external
store):

```julia
using DearDiary
DearDiary.run(; env_file=".env")
DearDiary.migrate_artifacts!()
```

The pass is idempotent and restartable: already-migrated rows carry a non-`inline` `backend`
value and are skipped, and a row that fails keeps its `inline` value for the next run.
