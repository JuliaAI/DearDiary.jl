const SQL_SELECT_MODELVERSION_BY_ID = """
    SELECT
        mv.id,
        mv.model_id,
        mv.version,
        mv.iteration_id,
        mv.resource_id,
        mv.stage_id,
        mv.description,
        mv.created_date,
        mv.updated_date
    FROM model_version mv WHERE mv.id = :id
    """

const SQL_SELECT_MODELVERSIONS_BY_MODEL_ID = """
    SELECT
        mv.id,
        mv.model_id,
        mv.version,
        mv.iteration_id,
        mv.resource_id,
        mv.stage_id,
        mv.description,
        mv.created_date,
        mv.updated_date
    FROM model_version mv WHERE mv.model_id = :id ORDER BY mv.version ASC
    """

const SQL_COUNT_MODELVERSIONS_BY_MODEL_ID = """
    SELECT COUNT(*) AS count FROM model_version WHERE model_id = :id
    """

# `version` is assigned inside the INSERT via a subquery — the service layer never supplies it
# directly. `UNIQUE(model_id, version)` on the table makes a concurrent insert from a racing
# writer fail with a Duplicate, which is then retried at the service layer.
const SQL_INSERT_MODELVERSION = """
    INSERT INTO model_version (
        model_id, version, iteration_id, resource_id, stage_id, description, created_date
    )
        VALUES (
            :model_id,
            COALESCE((SELECT MAX(version) FROM model_version WHERE model_id = :model_id), 0) + 1,
            :iteration_id,
            :resource_id,
            :stage_id,
            :description,
            :created_date
        ) RETURNING id
    """

const SQL_UPDATE_MODELVERSION = """
    UPDATE model_version SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_MODELVERSION = """
    DELETE FROM model_version
    WHERE id = :id
    """

const SQL_DELETE_MODELVERSIONS_BY_MODEL_ID = """
    DELETE FROM model_version
    WHERE model_id = :id
    """

# Used when promoting a sibling to `PRODUCTION` — every other version of the same model that
# currently holds `PRODUCTION` is moved to `ARCHIVED`, preserving the "at most one production
# version per model" invariant.
const SQL_ARCHIVE_PRODUCTION_SIBLINGS = """
    UPDATE model_version
    SET stage_id = :archived_stage, updated_date = :updated_date
    WHERE model_id = :model_id
      AND stage_id = :production_stage
      AND id <> :excluded_id
    """
