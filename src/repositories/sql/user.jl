const SQL_SELECT_USER_BY_USERNAME = "
SELECT
    us.ROWID as id,
    us.first_name,
    us.last_name,
    us.username,
    us.password,
    us.created_at,
    us.is_admin
FROM user us WHERE us.username = :username
"

const SQL_SELECT_USER_BY_ID = "
SELECT
    us.ROWID as id,
    us.first_name,
    us.last_name,
    us.username,
    us.password,
    us.created_at,
    us.is_admin
FROM user us WHERE us.ROWID = :id
"

const SQL_SELECT_USERS = "
SELECT
    us.ROWID as id,
    us.first_name,
    us.last_name,
    us.username,
    us.password,
    us.created_at,
    us.is_admin
FROM user us
"

const SQL_INSERT_USER = "
INSERT INTO user (username, password, first_name, last_name, created_at)
    VALUES (:username, :password, :first_name, :last_name, :created_at)
"

const SQL_UPDATE_USER = "
UPDATE user SET {fields}
WHERE ROWID = :id
"

const SQL_DELETE_USER = "
DELETE FROM user
WHERE ROWID = :id
"
