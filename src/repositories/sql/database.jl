const SQL_CREATE_USER = """
    CREATE TABLE IF NOT EXISTS user (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        first_name TEXT,
        last_name TEXT,
        username TEXT NOT NULL UNIQUE CHECK (username <> ''),
        password TEXT NOT NULL CHECK (password <> ''),
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        is_admin BIGINT DEFAULT 0
    )
    """

# NOTE: the default-user rules live in src/services/user.jl (DuckDB has no triggers).

const SQL_INSERT_DEFAULT_ADMIN_USER = """
    INSERT INTO user (first_name, last_name, username, password, created_date, is_admin)
        VALUES ('Default User', '', 'default', :password, :created_date, 1)
        ON CONFLICT DO NOTHING
    """

const SQL_CREATE_PROJECT = """
    CREATE TABLE IF NOT EXISTS project (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        name TEXT NOT NULL CHECK (name <> ''),
        description TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> '')
    )
    """

const SQL_CREATE_USERPERMISSION = """
    CREATE TABLE IF NOT EXISTS user_permission (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        user_id VARCHAR NOT NULL,
        project_id VARCHAR NOT NULL,
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
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        project_id VARCHAR NOT NULL,
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
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        experiment_id VARCHAR NOT NULL,
        notes TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        end_date TEXT DEFAULT '',
        parent_iteration_id VARCHAR REFERENCES iteration(id),
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
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        iteration_id VARCHAR NOT NULL,
        key TEXT NOT NULL CHECK (key <> ''),
        value TEXT NOT NULL CHECK (value <> ''),
        FOREIGN KEY(iteration_id) REFERENCES iteration(id)
    )
    """

const SQL_CREATE_METRIC = """
    CREATE TABLE IF NOT EXISTS metric (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        iteration_id VARCHAR NOT NULL,
        key TEXT NOT NULL CHECK (key <> ''),
        value DOUBLE NOT NULL,
        step BIGINT NOT NULL DEFAULT 0,
        recorded_at TEXT NOT NULL CHECK (recorded_at <> ''),
        FOREIGN KEY(iteration_id) REFERENCES iteration(id)
    )
    """

const SQL_CREATE_RESOURCE = """
    CREATE TABLE IF NOT EXISTS resource (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        experiment_id VARCHAR NOT NULL,
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
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        value TEXT NOT NULL UNIQUE CHECK (value <> '')
    )
    """

const SQL_CREATE_PROJECTTAG = """
    CREATE TABLE IF NOT EXISTS project_tag (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        project_id VARCHAR NOT NULL,
        tag_id VARCHAR NOT NULL,
        FOREIGN KEY(project_id) REFERENCES project(id),
        FOREIGN KEY(tag_id) REFERENCES tag(id),
        UNIQUE(project_id, tag_id)
    )
    """

const SQL_CREATE_EXPERIMENTTAG = """
    CREATE TABLE IF NOT EXISTS experiment_tag (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        experiment_id VARCHAR NOT NULL,
        tag_id VARCHAR NOT NULL,
        FOREIGN KEY(experiment_id) REFERENCES experiment(id),
        FOREIGN KEY(tag_id) REFERENCES tag(id),
        UNIQUE(experiment_id, tag_id)
    )
    """

const SQL_CREATE_ITERATIONTAG = """
    CREATE TABLE IF NOT EXISTS iteration_tag (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        iteration_id VARCHAR NOT NULL,
        tag_id VARCHAR NOT NULL,
        FOREIGN KEY(iteration_id) REFERENCES iteration(id),
        FOREIGN KEY(tag_id) REFERENCES tag(id),
        UNIQUE(iteration_id, tag_id)
    )
    """

const SQL_CREATE_MODEL = """
    CREATE TABLE IF NOT EXISTS model (
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        project_id VARCHAR NOT NULL,
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
        id VARCHAR PRIMARY KEY DEFAULT uuid(),
        model_id VARCHAR NOT NULL,
        version BIGINT NOT NULL CHECK (version > 0),
        iteration_id VARCHAR NOT NULL,
        resource_id VARCHAR,
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
