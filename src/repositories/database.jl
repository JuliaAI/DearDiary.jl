_DEARDIARY_DATABASE = nothing
const _DATABASE_LOCK = ReentrantLock()

"""
    get_database()::Union{DuckDB.DB,Nothing}

Return the active DuckDB connection, or `nothing` if the database has not been initialized.
"""
function get_database()::Union{DuckDB.DB,Nothing}
    global _DEARDIARY_DATABASE
    return _DEARDIARY_DATABASE
end

"""
    with_database_lock(f::Function)

Run `f()` while holding the lock that serialises every statement sent to the open DuckDB
connection, and return its result.

DuckDB does not accept concurrent use of one connection, while the REST server handles
requests on every thread Julia was started with and the dashboard server runs on the
interactive thread pool. Each repository helper takes the lock around its own statement. A
service takes it around a sequence that must not interleave with other requests, such as a
uniqueness check followed by an insert. The lock is reentrant, so nesting is safe.
"""
with_database_lock(f::Function) = lock(f, _DATABASE_LOCK)

"""
    initialize_database(; file_name::String="deardiary.db")

Open `file_name` (creating it if needed), run every pending [`Migration`](@ref) via
[`apply_migrations`](@ref), and re-seed the default user. A database that is already open
is closed first, so two instances never hold the same file. Calling this repeatedly is
safe: each migration runs at most once per database, and the default-user insert uses
`ON CONFLICT DO NOTHING`.
"""
function initialize_database(; file_name::String="deardiary.db")
    # Never hold two instances of the same file: the previous one must be fully closed
    # before a new one reads the file.
    close_database()
    with_database_lock() do
        db = DuckDB.DB(file_name)
        global _DEARDIARY_DATABASE = db
        apply_migrations(db)
        seed_default_user(db)
    end

    @info "Database initialized."
end

"""
    seed_default_user(db::DuckDB.DB)::Nothing

Insert the `default` admin user if it is not already present. The bcrypt hash and creation
timestamp are computed at call time, so this lives outside the SQL migration system (which
accepts only static SQL strings). The underlying `ON CONFLICT DO NOTHING` makes the call
idempotent.
"""
function seed_default_user(db::DuckDB.DB)::Nothing
    execute_statement(
        db,
        SQL_INSERT_DEFAULT_ADMIN_USER,
        (password=String(GenerateFromPassword("default")), created_date=(string(now()))),
    )
    return nothing
end

"""
    close_database()

Close the database if one is open. Every statement and result is destroyed as soon as it
has been read (see [`execute_query`](@ref)), so the `DB` object holds the last references
to the instance and `close!` shuts it down here, checkpointing the write-ahead log into
the file before this function returns.
"""
function close_database()
    # Detach under the lock: once the lock is ours no statement is in flight, and none can
    # start on this instance afterwards because `get_database` returns `nothing`.
    db = with_database_lock() do
        global _DEARDIARY_DATABASE
        instance = _DEARDIARY_DATABASE
        _DEARDIARY_DATABASE = nothing
        instance
    end
    isnothing(db) && return nothing

    DBInterface.close!(db)
    @info "Database connection closed."
    return nothing
end
