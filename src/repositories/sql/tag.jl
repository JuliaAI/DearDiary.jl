const SQL_SELECT_TAG_BY_ID = """
    SELECT * FROM tag WHERE id = :id
    """

const SQL_SELECT_TAG_BY_VALUE = """
    SELECT * FROM tag WHERE value = :value
    """

const SQL_SELECT_TAGS_BY_EXPERIMENT_ID = """
    SELECT t.id, t.value
    FROM tag t
    JOIN experiment_tag et ON t.id = et.tag_id
    WHERE et.experiment_id = :id
    """

const SQL_SELECT_TAGS_BY_PROJECT_ID = """
    SELECT t.id, t.value
    FROM tag t
    JOIN project_tag pt ON t.id = pt.tag_id
    WHERE pt.project_id = :id
    """

const SQL_SELECT_TAGS_BY_ITERATION_ID = """
    SELECT t.id, t.value
    FROM tag t
    JOIN iteration_tag it ON t.id = it.tag_id
    WHERE it.iteration_id = :id
    """

const SQL_INSERT_EXPERIMENT_TAG = """
    INSERT INTO experiment_tag (experiment_id, tag_id) VALUES (:experiment_id, :tag_id) RETURNING id
    """

const SQL_INSERT_PROJECT_TAG = """
    INSERT INTO project_tag (project_id, tag_id) VALUES (:project_id, :tag_id) RETURNING id
    """

const SQL_INSERT_ITERATION_TAG = """
    INSERT INTO iteration_tag (iteration_id, tag_id) VALUES (:iteration_id, :tag_id) RETURNING id
    """

const SQL_INSERT_TAG = """
    INSERT INTO tag (value) VALUES (:value) RETURNING id
    """

const SQL_DELETE_TAG = """
    DELETE FROM tag WHERE id = :id
    """
