const SQL_SELECT_PARAMETER_BY_ID = """
    SELECT
        p.id,
        p.iteration_id,
        p.key,
        p.value
    FROM parameter p WHERE p.id = :id
    """

const SQL_SELECT_PARAMETERS_BY_ITERATION_ID = """
    SELECT
        p.id,
        p.iteration_id,
        p.key,
        p.value
    FROM parameter p WHERE p.iteration_id = :id
    """

const SQL_COUNT_PARAMETERS_BY_ITERATION_ID = """
    SELECT COUNT(*) AS count FROM parameter WHERE iteration_id = :id
    """

const SQL_INSERT_PARAMETER = """
    INSERT INTO parameter (iteration_id, key, value)
        VALUES (:iteration_id, :key, :value) RETURNING id
    """

const SQL_UPDATE_PARAMETER = """
    UPDATE parameter SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_PARAMETER = """
    DELETE FROM parameter
    WHERE id = :id
    """

const SQL_DELETE_PARAMETERS_BY_ITERATION_ID = """
    DELETE FROM parameter
    WHERE iteration_id = :id
    """
