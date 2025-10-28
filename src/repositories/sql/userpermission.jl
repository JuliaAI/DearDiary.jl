const SQL_SELECT_USERPERMISSION_BY_ID = """
    SELECT 
        up.id,
        up.user_id,
        up.project_id,
        up.create_permission,
        up.read_permission,
        up.update_permission,
        up.delete_permission
    FROM user_permission up WHERE up.id = :id
    """

const SQL_SELECT_USERPERMISSION_BY_USERID_AND_PROJECT_ID = """
    SELECT 
        up.id,
        up.user_id,
        up.project_id,
        up.create_permission,
        up.read_permission,
        up.update_permission,
        up.delete_permission
    FROM user_permission up WHERE up.user_id = :user_id AND up.project_id = :project_id
    """

const SQL_INSERT_USERPERMISSION = """
    INSERT INTO user_permission (user_id, project_id)
        VALUES (:user_id, :project_id) RETURNING id
    """

const SQL_UPDATE_USERPERMISSION = """
    UPDATE user_permission SET {fields}
    WHERE id = :id
    """

const SQL_DELETE_USERPERMISSION = """
    DELETE FROM user_permission
    WHERE id = :id
    """

const SQL_DELETE_USERPERMISSIONS_BY_USER_ID = """
    DELETE FROM user_permission
    WHERE user_id = :id
    """

const SQL_DELETE_USERPERMISSIONS_BY_PROJECT_ID = """
    DELETE FROM user_permission
    WHERE project_id = :id
    """
