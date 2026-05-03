const SQL_SELECT_METRIC_BY_ID = """
    SELECT
        p.id,
        p.iteration_id,
        p.key,
        p.value
    FROM metric p WHERE p.id = :id
    """

const SQL_SELECT_METRICS_BY_ITERATION_ID = """
    SELECT
        p.id,
        p.iteration_id,
        p.key,
        p.value
    FROM metric p WHERE p.iteration_id = :id
    """

const SQL_COUNT_METRICS_BY_ITERATION_ID = """
    SELECT COUNT(*) AS count FROM metric WHERE iteration_id = :id
    """

const SQL_INSERT_METRIC = """
    INSERT INTO metric (iteration_id, key, value)
        VALUES (:iteration_id, :key, :value) RETURNING id
    """

const SQL_UPDATE_METRIC = """
    UPDATE metric SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_METRIC = """
    DELETE FROM metric
    WHERE id = :id
    """

const SQL_DELETE_METRICS_BY_ITERATION_ID = """
    DELETE FROM metric
    WHERE iteration_id = :id
    """
