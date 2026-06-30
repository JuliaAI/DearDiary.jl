"""
    Experiment <: ResultType

A struct representing an experiment within a project.

Fields
- `id::String`: The unique identifier of the experiment.
- `project_id::String`: The identifier of the project to which the experiment belongs.
- `status_id::Int64`: The status of the experiment.
- `name::String`: The name of the experiment.
- `description::String`: A description of the experiment.
- `created_date::DateTime`: The date and time when the experiment was created.
- `end_date::Optional{DateTime}`: The date and time when the experiment ended, or `nothing` if it is still ongoing.
"""
struct Experiment <: ResultType
    id::String
    project_id::String
    status_id::Int64
    name::String
    description::String
    created_date::DateTime
    end_date::Optional{DateTime}
end

struct ExperimentCreatePayload <: UpsertType
    status_id::Int64
    name::String
end

struct ExperimentUpdatePayload <: UpsertType
    status_id::Optional{Int64}
    name::Optional{String}
    description::Optional{String}
    end_date::Optional{DateTime}
end
