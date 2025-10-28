"""
    Project

A struct representing a project with its details.

# Fields
- `id::Integer`: The ID of the project.
- `name::String`: The name of the project.
- `description::String`: A brief description of the project.
- `created_date::DateTime`: The date and time the project was created.
"""
struct Project <: ResultType
    id::Integer
    name::String
    description::String
    created_date::DateTime
end

"""
    ProjectCreatePayload

A struct that represents the payload for creating a project.

# Fields
- `name::String`: The name of the project.
"""
struct ProjectCreatePayload <: UpsertType
    name::String
end

"""
    ProjectUpdatePayload

A struct that represents the payload for updating a project.

# Fields
- `name::Optional{String}`: The name of the project, or `nothing` if not updating.
- `description::Optional{String}`: A brief description of the project, or `nothing` if not updating.
"""
struct ProjectUpdatePayload <: UpsertType
    name::Optional{String}
    description::Optional{String}
end
