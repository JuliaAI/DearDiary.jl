"""
    UpsertResult

# Members
- `CREATED`: The record was successfully created.
- `UPDATED`: The record was successfully updated.
- `DUPLICATE`: The record already exists.
- `UNPROCESSABLE`: The record violates a constraint.
- `ERROR`: An error occurred while creating the record.
"""
@enum UpsertResult begin
    CREATED
    UPDATED
    DUPLICATE
    UNPROCESSABLE
    ERROR
end
