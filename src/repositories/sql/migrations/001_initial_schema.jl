"""
    MIGRATION_001_INITIAL_SCHEMA

Baseline schema as of the v0.6 release. Composed entirely from the `SQL_CREATE_*` constants
already defined in `src/repositories/sql/database.jl`, so the migration stays in lock-step
with the schema that the rest of the code references directly.

Existing v0.5.x databases were never tracked by `schema_migrations`; users carrying data
forward from a pre-v0.6 build must recreate their `.db` file.
"""
const MIGRATION_001_INITIAL_SCHEMA = Migration(
    1,
    "initial_schema",
    [
        SQL_CREATE_USER,
        SQL_PREVENT_DEFAULT_USER_DELETION,
        SQL_PREVENT_DEFAULT_USER_DEMOTE,
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
    ],
)
