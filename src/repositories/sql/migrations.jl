"""
    Migration

A forward-only schema migration applied by [`apply_migrations`](@ref).

Fields
- `version::Int`: Monotonically increasing version number. Determines application order and
  serves as the primary key in the `schema_migrations` tracking table. Once committed, do
  not reuse a version number.
- `name::String`: Short human-readable identifier (snake_case). Logged on application and
  stored alongside the version for debugging.
- `statements::Vector{String}`: SQL statements applied in order. Each statement runs through
  `DBInterface.execute`, matching how the rest of the repository talks to the database.
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
        version BIGINT PRIMARY KEY,
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

include("migrations/001_baseline.jl")

"""
    MIGRATIONS

The ordered registry of every [`Migration`](@ref) that ships with DearDiary. New schema
changes must append a new entry here (and add a numbered file under `migrations/`). Never
edit a previously-released migration in place: existing databases have already applied it
and will not re-run it.
"""
const MIGRATIONS = Migration[MIGRATION_001_BASELINE]

"""
    applied_versions(db::DuckDB.DB)::Set{Int}

Return the set of migration versions already recorded in `schema_migrations`. Creates the
tracking table on first call so a freshly-opened database needs no special bootstrap.
"""
function applied_versions(db::DuckDB.DB)::Set{Int}
    DBInterface.execute(db, duckdbify(SQL_CREATE_SCHEMA_MIGRATIONS))
    rows = DBInterface.execute(db, duckdbify(SQL_SELECT_SCHEMA_MIGRATIONS))
    return Set{Int}(row.version for row in Tables.namedtupleiterator(rows))
end

"""
    apply_migrations(db::DuckDB.DB)::Nothing

Apply every [`Migration`](@ref) in [`MIGRATIONS`](@ref) whose `version` is not yet recorded
in `schema_migrations`, in ascending order. Each migration's statements run sequentially via
`DBInterface.execute`; the version is stamped into `schema_migrations` only after every
statement succeeds, so a crash mid-migration leaves the registry untouched and the migration
is retried on next startup.

!!! warning
    Migrations are forward-only. There is no rollback story: every release moves the schema
    forward, never backward.
"""
function apply_migrations(db::DuckDB.DB)::Nothing
    applied = applied_versions(db)
    pending = [m for m in MIGRATIONS if !(m.version in applied)]

    for migration in (sort_migrations(pending))
        @info "Applying migration $(lpad(migration.version, 3, '0'))_$(migration.name)"
        for statement in migration.statements
            try
                DBInterface.execute(db, duckdbify(statement))
            catch exception
                if _is_idempotent_error(exception)
                    # Schema is already in the target state, typically because someone
                    # wiped `schema_migrations` on a DB whose tables were already migrated.
                    # Tolerate it so apply_migrations is safe to re-run. The version stamp
                    # is still recorded below, restoring the tracking table to consistency.
                    @debug "Skipping idempotent statement" statement exception
                else
                    rethrow(exception)
                end
            end
        end
        DBInterface.execute(
            db,
            duckdbify(SQL_INSERT_SCHEMA_MIGRATION),
            (version=migration.version, name=migration.name, applied_at=(string(now()))),
        )
    end
    return nothing
end

# True when `exception` signals the schema is already in the target state, meaning the
# statement would have been a no-op against a fresh DB anyway. The baseline uses
# `CREATE ... IF NOT EXISTS` throughout, so this only fires if someone wiped
# `schema_migrations` on an already-populated database.
function _is_idempotent_error(exception)::Bool
    return occursin("already exists", sprint(showerror, exception))
end

# Defensive sort: `MIGRATIONS` is expected to be in order, but a contributor adding an entry
# out of place should not silently break the application sequence.
sort_migrations(ms::AbstractVector{Migration}) = sort(ms; by=m -> m.version)
