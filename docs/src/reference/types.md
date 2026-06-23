# Types and internals

```@docs
DearDiary.User
DearDiary.UserResponse
DearDiary.UserPermission
DearDiary.Project
DearDiary.Experiment
DearDiary.Iteration
DearDiary.Parameter
DearDiary.Metric
DearDiary.Resource
DearDiary.Tag
DearDiary.Model
DearDiary.ModelVersion
DearDiary.Client
DearDiary.ClientError
```

## Database
```@docs
DearDiary.initialize_database
DearDiary.get_database
DearDiary.close_database
```

## Enumerations
```@docs
DearDiary.ExperimentStatus
DearDiary.IN_PROGRESS
DearDiary.STOPPED
DearDiary.FINISHED
DearDiary.IterationStatus
DearDiary.RUNNING
DearDiary.SUCCEEDED
DearDiary.FAILED
DearDiary.KILLED
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
DearDiary.error_code
```

## Pagination
```@docs
DearDiary.Pagination
DearDiary.PaginatedResponse
```
