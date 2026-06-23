const SQL_CREATE_SEQUENCES = [
    "CREATE SEQUENCE IF NOT EXISTS seq_user START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_project START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_user_permission START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_experiment START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_iteration START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_parameter START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_metric START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_resource START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_tag START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_project_tag START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_experiment_tag START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_iteration_tag START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_model START 1",
    "CREATE SEQUENCE IF NOT EXISTS seq_model_version START 1",
]

const SQL_CREATE_USER = """
    CREATE TABLE IF NOT EXISTS user (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_user'),
        first_name TEXT,
        last_name TEXT,
        username TEXT NOT NULL UNIQUE CHECK (username <> ''),
        password TEXT NOT NULL CHECK (password <> ''),
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        is_admin BIGINT DEFAULT 0
    )
    """

# NOTE: the two former triggers (prevent_default_user_deletion / _demote) are gone.
# DuckDB has no triggers. Those rules now live in src/services/user.jl (a later task).

const SQL_INSERT_DEFAULT_ADMIN_USER = """
    INSERT INTO user (first_name, last_name, username, password, created_date, is_admin)
        VALUES ('Default User', '', 'default', :password, :created_date, 1)
        ON CONFLICT DO NOTHING
    """

const SQL_CREATE_PROJECT = """
    CREATE TABLE IF NOT EXISTS project (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_project'),
        name TEXT NOT NULL CHECK (name <> ''),
        description TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> '')
    )
    """

const SQL_CREATE_USERPERMISSION = """
    CREATE TABLE IF NOT EXISTS user_permission (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_user_permission'),
        user_id BIGINT NOT NULL,
        project_id BIGINT NOT NULL,
        create_permission BIGINT DEFAULT 0,
        read_permission BIGINT DEFAULT 1,
        update_permission BIGINT DEFAULT 0,
        delete_permission BIGINT DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES user(id),
        FOREIGN KEY(project_id) REFERENCES project(id),
        UNIQUE(user_id, project_id)
    )
    """

const SQL_CREATE_EXPERIMENT = """
    CREATE TABLE IF NOT EXISTS experiment (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_experiment'),
        project_id BIGINT NOT NULL,
        status_id BIGINT NOT NULL CHECK (status_id IN (1, 2, 3)),
        name TEXT NOT NULL CHECK (name <> ''),
        description TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        end_date TEXT DEFAULT '',
        FOREIGN KEY(project_id) REFERENCES project(id)
    )
    """

const SQL_CREATE_ITERATION = """
    CREATE TABLE IF NOT EXISTS iteration (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_iteration'),
        experiment_id BIGINT NOT NULL,
        notes TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        end_date TEXT DEFAULT '',
        parent_iteration_id BIGINT REFERENCES iteration(id),
        status_id BIGINT NOT NULL DEFAULT 1 CHECK (status_id IN (1, 2, 3, 4)),
        error_message TEXT DEFAULT '',
        julia_version TEXT DEFAULT '',
        git_sha TEXT DEFAULT '',
        git_dirty BIGINT NOT NULL DEFAULT 0,
        entrypoint TEXT DEFAULT '',
        project_toml TEXT DEFAULT '',
        manifest_toml TEXT DEFAULT '',
        FOREIGN KEY(experiment_id) REFERENCES experiment(id)
    )
    """

const SQL_CREATE_PARAMETER = """
    CREATE TABLE IF NOT EXISTS parameter (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_parameter'),
        iteration_id BIGINT NOT NULL,
        key TEXT NOT NULL CHECK (key <> ''),
        value TEXT NOT NULL CHECK (value <> ''),
        FOREIGN KEY(iteration_id) REFERENCES iteration(id)
    )
    """

const SQL_CREATE_METRIC = """
    CREATE TABLE IF NOT EXISTS metric (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_metric'),
        iteration_id BIGINT NOT NULL,
        key TEXT NOT NULL CHECK (key <> ''),
        value DOUBLE NOT NULL,
        step BIGINT NOT NULL DEFAULT 0,
        recorded_at TEXT NOT NULL CHECK (recorded_at <> ''),
        FOREIGN KEY(iteration_id) REFERENCES iteration(id)
    )
    """

const SQL_CREATE_RESOURCE = """
    CREATE TABLE IF NOT EXISTS resource (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_resource'),
        experiment_id BIGINT NOT NULL,
        name TEXT NOT NULL CHECK (name <> ''),
        description TEXT DEFAULT '',
        data BLOB,
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        updated_date TEXT DEFAULT '',
        backend TEXT NOT NULL DEFAULT 'inline',
        uri TEXT DEFAULT '',
        size_bytes BIGINT NOT NULL DEFAULT 0,
        content_hash TEXT DEFAULT '',
        FOREIGN KEY(experiment_id) REFERENCES experiment(id)
    )
    """

const SQL_CREATE_TAG = """
    CREATE TABLE IF NOT EXISTS tag (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_tag'),
        value TEXT NOT NULL UNIQUE CHECK (value <> '')
    )
    """

const SQL_CREATE_PROJECTTAG = """
    CREATE TABLE IF NOT EXISTS project_tag (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_project_tag'),
        project_id BIGINT NOT NULL,
        tag_id BIGINT NOT NULL,
        FOREIGN KEY(project_id) REFERENCES project(id),
        FOREIGN KEY(tag_id) REFERENCES tag(id),
        UNIQUE(project_id, tag_id)
    )
    """

const SQL_CREATE_EXPERIMENTTAG = """
    CREATE TABLE IF NOT EXISTS experiment_tag (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_experiment_tag'),
        experiment_id BIGINT NOT NULL,
        tag_id BIGINT NOT NULL,
        FOREIGN KEY(experiment_id) REFERENCES experiment(id),
        FOREIGN KEY(tag_id) REFERENCES tag(id),
        UNIQUE(experiment_id, tag_id)
    )
    """

const SQL_CREATE_ITERATIONTAG = """
    CREATE TABLE IF NOT EXISTS iteration_tag (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_iteration_tag'),
        iteration_id BIGINT NOT NULL,
        tag_id BIGINT NOT NULL,
        FOREIGN KEY(iteration_id) REFERENCES iteration(id),
        FOREIGN KEY(tag_id) REFERENCES tag(id),
        UNIQUE(iteration_id, tag_id)
    )
    """

const SQL_CREATE_MODEL = """
    CREATE TABLE IF NOT EXISTS model (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_model'),
        project_id BIGINT NOT NULL,
        name TEXT NOT NULL CHECK (name <> ''),
        description TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        updated_date TEXT DEFAULT '',
        FOREIGN KEY(project_id) REFERENCES project(id),
        UNIQUE(project_id, name)
    )
    """

const SQL_CREATE_MODELVERSION = """
    CREATE TABLE IF NOT EXISTS model_version (
        id BIGINT PRIMARY KEY DEFAULT nextval('seq_model_version'),
        model_id BIGINT NOT NULL,
        version BIGINT NOT NULL CHECK (version > 0),
        iteration_id BIGINT NOT NULL,
        resource_id BIGINT,
        stage_id BIGINT NOT NULL CHECK (stage_id IN (1, 2, 3, 4)),
        description TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        updated_date TEXT DEFAULT '',
        FOREIGN KEY(model_id) REFERENCES model(id),
        FOREIGN KEY(iteration_id) REFERENCES iteration(id),
        FOREIGN KEY(resource_id) REFERENCES resource(id),
        UNIQUE(model_id, version)
    )
    """
