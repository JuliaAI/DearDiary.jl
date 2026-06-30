const SQL_SELECT_MODEL_BY_ID = """
    SELECT
        m.id,
        m.project_id,
        m.name,
        m.description,
        m.created_date,
        m.updated_date
    FROM model m WHERE m.id = :id
    """

const SQL_SELECT_MODELS_BY_PROJECT_ID = """
    SELECT
        m.id,
        m.project_id,
        m.name,
        m.description,
        m.created_date,
        m.updated_date
    FROM model m WHERE m.project_id = :id
    ORDER BY m.created_date ASC
    """

const SQL_COUNT_MODELS_BY_PROJECT_ID = """
    SELECT COUNT(*) AS count FROM model WHERE project_id = :id
    """

const SQL_INSERT_MODEL = """
    INSERT INTO model (project_id, name, created_date)
        VALUES (:project_id, :name, :created_date) RETURNING id
    """

const SQL_UPDATE_MODEL = """
    UPDATE model SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_MODEL = """
    DELETE FROM model
    WHERE id = :id
    """
