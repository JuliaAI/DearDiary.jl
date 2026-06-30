const SQL_SELECT_RESOURCE_BY_ID = """
    SELECT
        r.id,
        r.experiment_id,
        r.name,
        r.description,
        r.data,
        r.created_date,
        r.updated_date,
        r.backend,
        r.uri,
        r.size_bytes,
        r.content_hash
    FROM resource r WHERE r.id = :id
    """

const SQL_SELECT_RESOURCES_BY_EXPERIMENT_ID = """
    SELECT
        r.id,
        r.experiment_id,
        r.name,
        r.description,
        r.created_date,
        r.updated_date,
        r.backend,
        r.uri,
        r.size_bytes,
        r.content_hash
    FROM resource r WHERE r.experiment_id = :id
    ORDER BY r.created_date ASC
    """

const SQL_COUNT_RESOURCES_BY_EXPERIMENT_ID = """
    SELECT COUNT(*) AS count FROM resource WHERE experiment_id = :id
    """

const SQL_INSERT_RESOURCE = """
    INSERT INTO resource (
        experiment_id, name, data, created_date,
        backend, uri, size_bytes, content_hash
    )
        VALUES (
            :experiment_id, :name, :data, :created_date,
            :backend, :uri, :size_bytes, :content_hash
        ) RETURNING id
    """

const SQL_UPDATE_RESOURCE = """
    UPDATE resource SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_RESOURCE = """
    DELETE FROM resource
    WHERE id = :id
    """
