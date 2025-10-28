"""
    Experiment

A struct representing an experiment within a project.

# Fields
- `id::Integer`: The unique identifier of the experiment.
- `project_id::Integer`: The identifier of the project to which the experiment belongs.
- `status_id::Status`: The status of the experiment.
- `name::String`: The name of the experiment.
- `description::String`: A description of the experiment.
- `created_date::DateTime`: The date and time when the experiment was created.
- `end_date::Optional{DateTime}`: The date and time when the experiment ended, or `nothing` if it is still ongoing.
"""
struct Experiment <: ResultType
    id::Integer
    project_id::Integer
    status_id::Status
    name::String
    description::String
    created_date::DateTime
    end_date::Optional{DateTime}
end

"""
    ExperimentCreatePayload

A struct representing the payload for creating a new experiment.

# Fields
- `status_id::Status`: The status of the experiment.
- `name::String`: The name of the experiment.
- `description::String`: A description of the experiment.
"""
struct ExperimentCreatePayload <: UpsertType
    status_id::Status
    name::String
    description::String
end

"""
    ExperimentUpdatePayload

A struct representing the payload for updating an existing experiment.

# Fields
- `status_id::Optional{Status}`: The status of the experiment, or `nothing` if not updating.
- `name::Optional{String}`: The name of the experiment, or `nothing` if not updating.
- `description::Optional{String}`: A description of the experiment, or `nothing` if not updating.
- `end_date::Optional{DateTime}`: The date and time when the experiment ended, or `nothing` if not updating.
"""
struct ExperimentUpdatePayload <: UpsertType
    status_id::Optional{Status}
    name::Optional{String}
    description::Optional{String}
    end_date::Optional{DateTime}
end
