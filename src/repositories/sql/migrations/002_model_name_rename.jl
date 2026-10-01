# `SQL_CREATE_MODEL` without the `UNIQUE(project_id, name)` constraint. The baseline keeps
# the constrained version so a fresh database replays the same history as an upgraded one.
const SQL_CREATE_MODEL_WITHOUT_NAME_UNIQUE = """
    CREATE TABLE model (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        project_id VARCHAR NOT NULL,
        name TEXT NOT NULL CHECK (name <> ''),
        description TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        updated_date TEXT DEFAULT '',
        FOREIGN KEY(project_id) REFERENCES project(id)
    )
    """

"""
    MIGRATION_002_MODEL_NAME_RENAME

Recreates `model` without the `UNIQUE(project_id, name)` constraint so a model can be
renamed after versions have been registered. DuckDB runs an update of a unique-indexed
column as a delete followed by an insert, and the foreign key from `model_version` rejects
the delete. [`create_model`](@ref) and [`update_model`](@ref) enforce per-project name
uniqueness instead.

Both registry tables are copied aside, dropped, created again, and refilled inside one
transaction. The tables are never renamed: DuckDB keeps its foreign-key bookkeeping under
the original table name, so a renamed table later breaks deletes on `project`. The final
`CHECKPOINT` folds the schema change into the database file instead of leaving it in the
write-ahead log.
"""
const MIGRATION_002_MODEL_NAME_RENAME = Migration(
    2,
    "model_name_rename",
    [
        "BEGIN TRANSACTION",
        "CREATE TABLE model_backup AS SELECT * FROM model",
        "CREATE TABLE model_version_backup AS SELECT * FROM model_version",
        "DROP TABLE model_version",
        "DROP TABLE model",
        SQL_CREATE_MODEL_WITHOUT_NAME_UNIQUE,
        """
        INSERT INTO model (id, project_id, name, description, created_date, updated_date)
            SELECT id, project_id, name, description, created_date, updated_date
            FROM model_backup
        """,
        SQL_CREATE_MODELVERSION,
        """
        INSERT INTO model_version (id, model_id, version, iteration_id, resource_id, stage_id,
                                   description, created_date, updated_date)
            SELECT id, model_id, version, iteration_id, resource_id, stage_id, description,
                   created_date, updated_date
            FROM model_version_backup
        """,
        "DROP TABLE model_version_backup",
        "DROP TABLE model_backup",
        "COMMIT",
        "CHECKPOINT",
    ],
)
