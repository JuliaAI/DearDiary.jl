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

Initializes the database by creating the necessary tables.
"""
function initialize_database(; file_name::String="deardiary.db")
    global _DEARDIARY_DATABASE = SQLite.DB(file_name)

    # Enable foreign key constraints
    DBInterface.execute(_DEARDIARY_DATABASE, "PRAGMA foreign_keys = ON")

    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_USER)
    DBInterface.execute(
        _DEARDIARY_DATABASE,
        SQL_INSERT_DEFAULT_ADMIN_USER,
        (password=GenerateFromPassword("default") |> String,),
    )
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_PREVENT_DEFAULT_USER_DELETION)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_PREVENT_DEFAULT_USER_DEMOTE)

    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_PROJECT)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_USERPERMISSION)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_EXPERIMENT)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_ITERATION)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_PARAMETER)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_METRIC)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_RESOURCE)

    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_TAG)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_PROJECTTAG)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_EXPERIMENTTAG)
    DBInterface.execute(_DEARDIARY_DATABASE, SQL_CREATE_ITERATIONTAG)

    @info "Database initialized successfully."
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
