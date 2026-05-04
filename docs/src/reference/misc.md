# Miscellaneous
## Database
```@docs
DearDiary.initialize_database
DearDiary.get_database
DearDiary.close_database
```

## Enumerations
```@docs
DearDiary.Status
DearDiary.IN_PROGRESS
DearDiary.STOPPED
DearDiary.FINISHED
```

## Marker types
### Upsert results
```@docs
DearDiary.UpsertResult
DearDiary.Created
DearDiary.Updated
DearDiary.Duplicate
DearDiary.Unprocessable
DearDiary.Error
```

### Permission actions
```@docs
DearDiary.PermissionAction
DearDiary.CreatePermission
DearDiary.ReadPermission
DearDiary.UpdatePermission
DearDiary.DeletePermission
```

### Error codes
```@docs
DearDiary.ErrorCode
DearDiary.NotFound
DearDiary.InvalidCredentials
DearDiary.TokenMissing
DearDiary.TokenInvalid
DearDiary.TokenExpired
DearDiary.TokenPayloadInvalid
DearDiary.UserNotFound
DearDiary.AdminRequired
DearDiary.SameUserRequired
DearDiary.ProjectPermissionRequired
DearDiary.Conflict
DearDiary.InvalidPayload
DearDiary.ServerError
```

## Pagination
```@docs
DearDiary.Pagination
DearDiary.PaginatedResponse
```
