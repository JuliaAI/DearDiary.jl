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
@memoize get_database()::SQLite.DB = SQLite.DB(api_config.db_file)

"""
    initialize_database(; database::SQLite.DB=get_database())

Initializes the database by creating the necessary tables.
"""
function initialize_database(; database::SQLite.DB=get_database())
    DBInterface.execute(database, SQL_CREATE_USER)
    DBInterface.execute(database, SQL_CREATE_PROJECT)
    DBInterface.execute(database, SQL_CREATE_USERPROJECT)
end
