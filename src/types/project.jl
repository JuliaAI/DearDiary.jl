"""
    Project <: ResultType

A struct representing a project with its details.

Fields
- `id::String`: The ID of the project.
- `name::String`: The name of the project.
- `description::String`: A brief description of the project.
- `created_date::DateTime`: The date and time the project was created.
"""
struct Project <: ResultType
    id::String
    name::String
    description::String
    created_date::DateTime
end

struct ProjectCreatePayload <: UpsertType
    name::String
end

struct ProjectUpdatePayload <: UpsertType
    name::Optional{String}
    description::Optional{String}
end
