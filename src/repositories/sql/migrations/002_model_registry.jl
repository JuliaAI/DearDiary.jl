"""
    MIGRATION_002_MODEL_REGISTRY

Introduces the model registry tables `model` and `model_version`. Both statements are
`CREATE TABLE IF NOT EXISTS`, so re-running the migration on a database that somehow already
holds the tables is a no-op — but per the migration contract, each `version` runs at most
once anyway.

A registered [`Model`](@ref) is project-scoped (unique name per project). A
[`ModelVersion`](@ref) is uniquely identified by `(model_id, version)` and tracks lineage to
the producing [`Iteration`](@ref) plus an optional pointer at the artifact [`Resource`](@ref).
"""
const MIGRATION_002_MODEL_REGISTRY = Migration(
    2,
    "model_registry",
    [
        SQL_CREATE_MODEL,
        SQL_CREATE_MODELVERSION,
    ],
)
