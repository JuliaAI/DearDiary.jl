const SQL_SELECT_PROJECT_BY_ID = """
    SELECT
        p.id,
        p.name,
        p.description,
        p.created_date
    FROM project p WHERE id = :id
    """

const SQL_SELECT_PROJECTS = """
    SELECT
        p.id,
        p.name,
        p.description,
        p.created_date
    FROM project p
    """

const SQL_INSERT_PROJECT = """
    INSERT INTO project (name, created_date)
        VALUES (:name, :created_date) RETURNING id
    """

const SQL_UPDATE_PROJECT = """
    UPDATE project SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_PROJECT = """
    DELETE FROM project
    WHERE id = :id
    """
