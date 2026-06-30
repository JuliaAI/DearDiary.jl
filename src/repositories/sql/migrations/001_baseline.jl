"""
    MIGRATION_001_BASELINE

The v0.9 DuckDB-native baseline schema. Creates every table in its final v0.9 shape (the
columns that pre-DuckDB releases added incrementally via migrations 002-005 are declared
inline here). DuckDB cannot open old SQLite `.db` files, so operators must start from a
fresh DB. The `Migration` framework is retained for future schema changes.
"""
const MIGRATION_001_BASELINE = Migration(
    1,
    "baseline",
    [
        SQL_CREATE_USER,
        SQL_CREATE_PROJECT,
        SQL_CREATE_USERPERMISSION,
        SQL_CREATE_EXPERIMENT,
        SQL_CREATE_ITERATION,
        SQL_CREATE_PARAMETER,
        SQL_CREATE_METRIC,
        SQL_CREATE_RESOURCE,
        SQL_CREATE_TAG,
        SQL_CREATE_PROJECTTAG,
        SQL_CREATE_EXPERIMENTTAG,
        SQL_CREATE_ITERATIONTAG,
        SQL_CREATE_MODEL,
        SQL_CREATE_MODELVERSION,
    ],
)
