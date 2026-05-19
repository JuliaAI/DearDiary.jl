"""
    Model <: ResultType

A struct representing a registered model in the project-scoped model registry. A `Model` is
the named container under which one or more [`ModelVersion`](@ref) checkpoints are recorded.

Fields
- `id::Int64`: The unique identifier of the model.
- `project_id::Int64`: The identifier of the [`Project`](@ref) that owns the model.
- `name::String`: The registry-unique name of the model (unique per project).
- `description::String`: A free-form description of the model.
- `created_date::DateTime`: The date and time when the model was registered.
- `updated_date::Optional{DateTime}`: The date and time of the most recent update, or
  `nothing` if the record has never been updated.
"""
struct Model <: ResultType
    id::Int64
    project_id::Int64
    name::String
    description::String
    created_date::DateTime
    updated_date::Optional{DateTime}
end

struct ModelCreatePayload <: UpsertType
    name::String
    description::Optional{String}
end

struct ModelUpdatePayload <: UpsertType
    name::Optional{String}
    description::Optional{String}
end
