const SQL_SELECT_ITERATION_BY_ID = """
    SELECT
        i.id,
        i.experiment_id,
        i.notes,
        i.created_date,
        i.end_date
    FROM iteration i WHERE i.id = :id
    """

const SQL_SELECT_ITERATIONS_BY_EXPERIMENT_ID = """
    SELECT
        i.id,
        i.experiment_id,
        i.notes,
        i.created_date,
        i.end_date
    FROM iteration i WHERE i.experiment_id = :id
    """

const SQL_COUNT_ITERATIONS_BY_EXPERIMENT_ID = """
    SELECT COUNT(*) AS count FROM iteration WHERE experiment_id = :id
    """

const SQL_INSERT_ITERATION = """
    INSERT INTO iteration (experiment_id, created_date)
        VALUES (:experiment_id, :created_date) RETURNING id
    """

const SQL_UPDATE_ITERATION = """
    UPDATE iteration SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_ITERATION = """
    DELETE FROM iteration
    WHERE id = :id
    """
