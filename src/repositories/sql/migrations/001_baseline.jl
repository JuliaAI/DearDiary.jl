"""
    MIGRATION_001_BASELINE

The baseline schema. Creates every table with `CREATE TABLE IF NOT EXISTS`, so running it
against a database that already has the tables is a no-op. DuckDB cannot open database
files written by the SQLite-backed releases, so those deployments start from a fresh file.
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
