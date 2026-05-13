_DEARDIARY_DATABASE = nothing

"""
    get_database()::Union{SQLite.DB,Nothing}

Returns a SQLite database connection. If the database has not been initialized, it returns `nothing`.

# Returns
A [SQLite.DB](https://juliadatabases.org/SQLite.jl/stable/#SQLite.DB) object, or `nothing` if the database is not initialized.
"""
function get_database()::Union{SQLite.DB,Nothing}
    global _DEARDIARY_DATABASE
    return _DEARDIARY_DATABASE
end

"""
    initialize_database(; file_name::String="deardiary.db")

Open `file_name` (creating it if needed), run every pending [`Migration`](@ref) via
[`apply_migrations`](@ref), and re-seed the default user. Safe to call repeatedly: each
migration runs at most once per database, and the default-user `INSERT OR IGNORE` is a
no-op when the row already exists.
"""
function initialize_database(; file_name::String="deardiary.db")
    global _DEARDIARY_DATABASE = SQLite.DB(file_name)

    # Enable foreign key constraints
    DBInterface.execute(_DEARDIARY_DATABASE, "PRAGMA foreign_keys = ON")

    apply_migrations(_DEARDIARY_DATABASE)
    seed_default_user(_DEARDIARY_DATABASE)

    @info "Database initialized successfully."
end

"""
    seed_default_user(db::SQLite.DB)::Nothing

Insert the seeded `default` admin user when it is not already present. The bcrypt hash is
derived at call time, so this lives outside the SQL migration system (which is restricted to
static SQL strings). The underlying `INSERT OR IGNORE` makes the call idempotent.
"""
function seed_default_user(db::SQLite.DB)::Nothing
    DBInterface.execute(
        db,
        SQL_INSERT_DEFAULT_ADMIN_USER,
        (password=GenerateFromPassword("default") |> String,),
    )
    return nothing
end

"""
    close_database()

Closes the database connection if it is open.
"""
function close_database()
    global _DEARDIARY_DATABASE

    if !(_DEARDIARY_DATABASE |> isnothing)
        _DEARDIARY_DATABASE |> SQLite.close
        _DEARDIARY_DATABASE = nothing
        @info "Database connection closed."
    end
end
