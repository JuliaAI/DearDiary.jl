const SQL_CREATE_USER = "
CREATE TABLE IF NOT EXISTS user (
    first_name TEXT,
    last_name TEXT,
    username TEXT NOT NULL CHECK (username <> ''),
    password TEXT NOT NULL CHECK (password <> ''),
    created_at TEXT NOT NULL CHECK (created_at <> ''),
    is_admin INTEGER DEFAULT 0,
    PRIMARY KEY (username)
)
"

const SQL_CREATE_PROJECT = "
CREATE TABLE IF NOT EXISTS project (
    name TEXT,
    description TEXT,
    created_at TEXT NOT NULL CHECK (created_at <> ''),
    updated_at TEXT NOT NULL CHECK (updated_at <> ''),
    archived INTEGER DEFAULT 0
)
"

const SQL_CREATE_USERPROJECT = "
CREATE TABLE IF NOT EXISTS user_project (
    user_id INTEGER,
    project_id INTEGER,
    created_at TEXT NOT NULL CHECK (created_at <> ''),
    is_admin INTEGER DEFAULT 0,
    FOREIGN KEY(user_id) REFERENCES user(rowid),
    FOREIGN KEY(project_id) REFERENCES project(rowid)
)
"
