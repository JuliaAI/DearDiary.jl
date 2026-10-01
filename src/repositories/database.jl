_DEARDIARY_DATABASE = nothing

"""
    get_database()::Union{DuckDB.DB,Nothing}

Return the active DuckDB connection, or `nothing` if the database has not been initialized.
"""
function get_database()::Union{DuckDB.DB,Nothing}
    global _DEARDIARY_DATABASE
    return _DEARDIARY_DATABASE
end

"""
    initialize_database(; file_name::String="deardiary.db")

Open `file_name` (creating it if needed), run every pending [`Migration`](@ref) via
[`apply_migrations`](@ref), and re-seed the default user. A database that is already open
is closed first, so two instances never hold the same file. Calling this repeatedly is
safe: each migration runs at most once per database, and the default-user insert uses
`ON CONFLICT DO NOTHING`.
"""
function initialize_database(; file_name::String="deardiary.db")
    global _DEARDIARY_DATABASE
    # Never hold two instances of the same file: the previous one must be fully closed
    # before a new one reads the file.
    isnothing(_DEARDIARY_DATABASE) || close_database()
    _DEARDIARY_DATABASE = DuckDB.DB(file_name)

    apply_migrations(_DEARDIARY_DATABASE)
    seed_default_user(_DEARDIARY_DATABASE)

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
    DBInterface.execute(
        db,
        duckdbify(SQL_INSERT_DEFAULT_ADMIN_USER),
        (password=String(GenerateFromPassword("default")), created_date=(string(now()))),
    )
    return nothing
end

"""
    close_database()

Close the database if one is open. Garbage is collected before and after the close so
DuckDB finalizers release the instance and its write-ahead log is checkpointed before this
function returns.
"""
function close_database()
    global _DEARDIARY_DATABASE

    if !(isnothing(_DEARDIARY_DATABASE))
        # DuckDB.jl releases prepared statements and results through finalizers, and each of
        # them keeps the database instance alive. Collecting them first lets `close!` really
        # shut the instance down, so the write-ahead log is checkpointed before this
        # function returns instead of at some later collection, possibly while another
        # handle to the same file is already open.
        GC.gc()
        DBInterface.close!(_DEARDIARY_DATABASE)
        _DEARDIARY_DATABASE = nothing
        GC.gc()
        @info "Database connection closed."
    end
end
