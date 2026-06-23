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
[`apply_migrations`](@ref), and re-seed the default user. Calling this repeatedly is safe:
each migration runs at most once per database, and the default-user insert uses
`ON CONFLICT DO NOTHING`.
"""
function initialize_database(; file_name::String="deardiary.db")
    global _DEARDIARY_DATABASE = DuckDB.DB(file_name)

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
        (
            password=String(GenerateFromPassword("default")),
            created_date=(string(now())),
        ),
    )
    return nothing
end

"""
    close_database()

Close the database connection if one is open.
"""
function close_database()
    global _DEARDIARY_DATABASE

    if !(isnothing(_DEARDIARY_DATABASE))
        DBInterface.close!(_DEARDIARY_DATABASE)
        _DEARDIARY_DATABASE = nothing
        @info "Database connection closed."
    end
end
