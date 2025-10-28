"""
    get_database()::SQLite.DB

Returns a SQLite database connection. The database file is specified by the
`TRACKINGAPI_DB_FILE` environment variable. If the variable is not set, the
default value is `trackingapi.db` in the current directory.

# Returns
A [`SQLite.DB`](@ref) object.

!!! note
The function is memoized, so the database connection will be reused across calls.
"""
@memoize function get_database()::SQLite.DB
    if isdefined(Main, :api_config)
        return SQLite.DB(api_config.db_file)
    else
        return SQLite.DB("trackingapi.db")
    end
end

"""
    initialize_database(; database::SQLite.DB=get_database())

Initializes the database by creating the necessary tables.
"""
function initialize_database(; database::SQLite.DB=get_database())
    # Enable foreign key constraints
    DBInterface.execute(database, "PRAGMA foreign_keys = ON")

    DBInterface.execute(database, SQL_CREATE_USER)
    DBInterface.execute(database,replace(SQL_INSERT_DEFAULT_ADMIN_USER, "{password}" => GenerateFromPassword("default") |> String))
    DBInterface.execute(database, SQL_PREVENT_DEFAULT_USER_DELETION)
    DBInterface.execute(database, SQL_PREVENT_DEFAULT_USER_DEMOTE)

    DBInterface.execute(database, SQL_CREATE_PROJECT)
    DBInterface.execute(database, SQL_CREATE_USERPERMISSION)

    DBInterface.execute(database, SQL_CREATE_TAG)
    DBInterface.execute(database, SQL_CREATE_PROJECTTAG)
end
