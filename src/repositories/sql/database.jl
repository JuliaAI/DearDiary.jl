const SQL_CREATE_USER = """
    CREATE TABLE IF NOT EXISTS user (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT,
        last_name TEXT,
        username TEXT NOT NULL UNIQUE CHECK (username <> ''),
        password TEXT NOT NULL CHECK (password <> ''),
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        is_admin INTEGER DEFAULT 0
    )
    """

const SQL_INSERT_DEFAULT_ADMIN_USER = """
    INSERT OR IGNORE INTO user (first_name, last_name, username, password, created_date, is_admin)
        VALUES ('Default User', '', 'default', :password, strftime('%Y-%m-%dT%H:%M:%f', 'now'), 1)
    """

const SQL_PREVENT_DEFAULT_USER_DELETION = """
    CREATE TRIGGER IF NOT EXISTS prevent_default_user_deletion
    BEFORE DELETE ON user
    FOR EACH ROW
    WHEN OLD.username = 'default'
    BEGIN
        SELECT RAISE(ABORT, 'Cannot delete the default user.');
    END;
    """

const SQL_PREVENT_DEFAULT_USER_DEMOTE = """
    CREATE TRIGGER IF NOT EXISTS prevent_default_user_demote
    BEFORE UPDATE OF is_admin ON user
    FOR EACH ROW
    WHEN OLD.username = 'default' AND NEW.is_admin = 0
    BEGIN
        SELECT RAISE(ABORT, 'Cannot demote the default user from admin.');
    END;
    """

const SQL_CREATE_PROJECT = """
    CREATE TABLE IF NOT EXISTS project (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL CHECK (name <> ''),
        description TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> '')
    )
    """

const SQL_CREATE_USERPERMISSION = """
    CREATE TABLE IF NOT EXISTS user_permission (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        project_id INTEGER NOT NULL,
        create_permission INTEGER DEFAULT 0,
        read_permission INTEGER DEFAULT 1,
        update_permission INTEGER DEFAULT 0,
        delete_permission INTEGER DEFAULT 0,
        FOREIGN KEY(user_id) REFERENCES user(id),
        FOREIGN KEY(project_id) REFERENCES project(id),
        UNIQUE(user_id, project_id)
    )
    """

const SQL_CREATE_EXPERIMENT = """
    CREATE TABLE IF NOT EXISTS experiment (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        status_id INTEGER NOT NULL CHECK (status_id IN (1, 2, 3)),
        name TEXT NOT NULL CHECK (name <> ''),
        description TEXT DEFAULT '',
        created_date TEXT NOT NULL CHECK (created_date <> ''),
        end_date TEXT DEFAULT '',
        FOREIGN KEY(project_id) REFERENCES project(id)
    )
    """

const SQL_CREATE_TAG = """
    CREATE TABLE IF NOT EXISTS tag (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        value TEXT NOT NULL CHECK (value <> '')
    )
    """

const SQL_CREATE_PROJECTTAG = """
    CREATE TABLE IF NOT EXISTS project_tag (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        FOREIGN KEY(project_id) REFERENCES project(id),
        FOREIGN KEY(tag_id) REFERENCES tag(id)
    )
    """
