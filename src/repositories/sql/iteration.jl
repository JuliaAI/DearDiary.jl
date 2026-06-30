const _SQL_ITERATION_COLUMNS = """
    i.id,
    i.experiment_id,
    i.notes,
    i.created_date,
    i.end_date,
    i.parent_iteration_id,
    i.status_id,
    i.error_message,
    i.julia_version,
    i.git_sha,
    i.git_dirty,
    i.entrypoint,
    i.project_toml,
    i.manifest_toml
    """

const SQL_SELECT_ITERATION_BY_ID = """
    SELECT
        $(_SQL_ITERATION_COLUMNS)
    FROM iteration i WHERE i.id = :id
    """

const SQL_SELECT_ITERATIONS_BY_EXPERIMENT_ID = """
    SELECT
        $(_SQL_ITERATION_COLUMNS)
    FROM iteration i WHERE i.experiment_id = :id
    ORDER BY i.created_date ASC
    """

const SQL_SELECT_ITERATIONS_BY_PARENT_ID = """
    SELECT
        $(_SQL_ITERATION_COLUMNS)
    FROM iteration i WHERE i.parent_iteration_id = :id ORDER BY i.created_date ASC
    """

const SQL_COUNT_ITERATIONS_BY_EXPERIMENT_ID = """
    SELECT COUNT(*) AS count FROM iteration WHERE experiment_id = :id
    """

const SQL_INSERT_ITERATION = """
    INSERT INTO iteration (experiment_id, created_date, parent_iteration_id, status_id)
        VALUES (:experiment_id, :created_date, :parent_iteration_id, :status_id) RETURNING id
    """

const SQL_UPDATE_ITERATION = """
    UPDATE iteration SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_ITERATION = """
    DELETE FROM iteration
    WHERE id = :id
    """

const SQL_NULLIFY_ITERATION_CHILDREN = """
    UPDATE iteration SET parent_iteration_id = NULL WHERE parent_iteration_id = :id
    """
