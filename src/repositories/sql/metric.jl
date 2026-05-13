const SQL_SELECT_METRIC_BY_ID = """
    SELECT
        p.id,
        p.iteration_id,
        p.key,
        p.value,
        p.step,
        p.recorded_at
    FROM metric p WHERE p.id = :id
    """

const SQL_SELECT_METRICS_BY_ITERATION_ID = """
    SELECT
        p.id,
        p.iteration_id,
        p.key,
        p.value,
        p.step,
        p.recorded_at
    FROM metric p WHERE p.iteration_id = :id
    ORDER BY p.step ASC, p.id ASC
    """

const SQL_COUNT_METRICS_BY_ITERATION_ID = """
    SELECT COUNT(*) AS count FROM metric WHERE iteration_id = :id
    """

const SQL_SELECT_NEXT_METRIC_STEP = """
    SELECT COALESCE(MAX(step), -1) + 1 AS next_step
    FROM metric
    WHERE iteration_id = :iteration_id AND key = :key
    """

const SQL_INSERT_METRIC = """
    INSERT INTO metric (iteration_id, key, value, step, recorded_at)
        VALUES (:iteration_id, :key, :value, :step, :recorded_at) RETURNING id
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
