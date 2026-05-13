"""
    Migration

A forward-only schema migration applied by [`apply_migrations`](@ref).

Fields
- `version::Int`: Monotonically increasing version number. Determines application order and
  is the primary key in the `schema_migrations` tracking table — once a version is committed,
  do not reuse it.
- `name::String`: Short human-readable identifier (snake_case). Logged on application and
  stored alongside the version for debugging.
- `statements::Vector{String}`: SQL statements applied in order. Each statement runs through
  `DBInterface.execute`, matching how the rest of the repository talks to SQLite.
"""
struct Migration
    version::Int
    name::String
    statements::Vector{String}
end

"""
    SQL_CREATE_SCHEMA_MIGRATIONS

Bootstrap table that records which [`Migration`](@ref)s have already run against a database.
Created on demand by [`apply_migrations`](@ref) so a fresh DB can be initialised without
manual setup.
"""
const SQL_CREATE_SCHEMA_MIGRATIONS = """
    CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        applied_at TEXT NOT NULL
    )
    """

const SQL_INSERT_SCHEMA_MIGRATION = """
    INSERT INTO schema_migrations (version, name, applied_at)
        VALUES (:version, :name, :applied_at)
    """

const SQL_SELECT_SCHEMA_MIGRATIONS = """
    SELECT version FROM schema_migrations ORDER BY version
    """

include("migrations/001_initial_schema.jl")

"""
    MIGRATIONS

The ordered registry of every [`Migration`](@ref) that ships with DearDiary. New schema
changes must append a new entry here (and add a numbered file under `migrations/`); never
edit a previously-released migration in place — existing databases have already applied it
and will not re-run it.
"""
const MIGRATIONS = Migration[
    MIGRATION_001_INITIAL_SCHEMA,
]

"""
    applied_versions(db::SQLite.DB)::Set{Int}

Return the set of migration versions already recorded in `schema_migrations`. Creates the
tracking table on first call so a freshly-opened database needs no special bootstrap.
"""
function applied_versions(db::SQLite.DB)::Set{Int}
    DBInterface.execute(db, SQL_CREATE_SCHEMA_MIGRATIONS)
    rows = DBInterface.execute(db, SQL_SELECT_SCHEMA_MIGRATIONS)
    return Set{Int}(row.version for row in rows)
end

"""
    apply_migrations(db::SQLite.DB)::Nothing

Apply every [`Migration`](@ref) in [`MIGRATIONS`](@ref) whose `version` is not yet recorded
in `schema_migrations`, in ascending order. Each migration's statements run sequentially via
`DBInterface.execute`; the version is stamped into `schema_migrations` only after every
statement succeeds, so a crash mid-migration leaves the registry untouched and the migration
is retried on next startup.

!!! warning
    Migrations are forward-only. There is no rollback story — the contract is "every release
    moves the schema forward, never backward."
"""
function apply_migrations(db::SQLite.DB)::Nothing
    applied = db |> applied_versions
    pending = [m for m in MIGRATIONS if !(m.version in applied)]

    for migration in (pending |> sort_migrations)
        @info "Applying migration $(lpad(migration.version, 3, '0'))_$(migration.name)"
        for statement in migration.statements
            DBInterface.execute(db, statement)
        end
        DBInterface.execute(
            db,
            SQL_INSERT_SCHEMA_MIGRATION,
            (
                version=migration.version,
                name=migration.name,
                applied_at=(now() |> string),
            ),
        )
    end
    return nothing
end

# Defensive sort — `MIGRATIONS` is expected to be in order, but a contributor adding an entry
# out of place should not silently break the application sequence.
sort_migrations(ms::AbstractVector{Migration}) = sort(ms; by=m -> m.version)
