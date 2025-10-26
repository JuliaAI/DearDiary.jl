const SQL_SELECT_USER_BY_USERNAME = "
SELECT
    u.id,
    u.first_name,
    u.last_name,
    u.username,
    u.password,
    u.created_date,
    u.is_admin
FROM user u WHERE u.username = :username
"

const SQL_SELECT_USER_BY_ID = "
SELECT
    u.id,
    u.first_name,
    u.last_name,
    u.username,
    u.password,
    u.created_date,
    u.is_admin
FROM user u WHERE u.id = :id
"

const SQL_SELECT_USERS = "
SELECT
    u.id,
    u.first_name,
    u.last_name,
    u.username,
    u.password,
    u.created_date,
    u.is_admin
FROM user u
"

const SQL_SELECT_USERS_BY_PROJECT_ID = "
SELECT
    u.id,
    u.first_name,
    u.last_name,
    u.username,
    u.password,
    u.created_date,
    u.is_admin
FROM user u
INNER JOIN user_permission up ON u.id = up.user_id
WHERE up.project_id = :project_id
"

const SQL_INSERT_USER = "
INSERT INTO user (username, password, first_name, last_name, created_date)
    VALUES (:username, :password, :first_name, :last_name, :created_date) RETURNING id
"

const SQL_UPDATE_USER = "
UPDATE user SET {fields}
WHERE id = :id
"

const SQL_DELETE_USER = "
DELETE FROM user
WHERE id = :id
"
