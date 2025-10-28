const SQL_SELECT_EXPERIMENT_BY_ID = """
    SELECT
        e.id,
        e.project_id,
        e.status_id,
        e.name,
        e.description,
        e.created_date,
        e.end_date
    FROM experiment e WHERE e.id = :id
    """

const SQL_SELECT_EXPERIMENTS_BY_PROJECT_ID = """
    SELECT
        e.id,
        e.project_id,
        e.status_id,
        e.name,
        e.description,
        e.created_date,
        e.end_date
    FROM experiment e WHERE e.project_id = :id
    """

const SQL_INSERT_EXPERIMENT = """
    INSERT INTO experiment (project_id, status_id, name, created_date)
        VALUES (:project_id, :status_id, :name, :created_date) RETURNING id
    """

const SQL_UPDATE_EXPERIMENT = """
    UPDATE experiment SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_EXPERIMENT = """
    DELETE FROM experiment
    WHERE id = :id
    """
