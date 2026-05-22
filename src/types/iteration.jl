"""
    Iteration <: ResultType

A struct representing an iteration within an experiment.

Fields
- `id::Int64`: The unique identifier of the iteration.
- `experiment_id::Int64`: The identifier of the experiment to which the iteration belongs.
- `notes::String`: Notes associated with the iteration.
- `created_date::DateTime`: The date and time when the iteration was created.
- `end_date::Optional{DateTime}`: The date and time when the iteration ended, or `nothing`
  if it is still ongoing.
- `parent_iteration_id::Optional{Int64}`: The identifier of the parent [`Iteration`](@ref)
  when this iteration is a child run (e.g. one trial in an HPO sweep, one fold in a nested
  CV, one worker in a distributed run). `nothing` for top-level iterations.
- `status_id::Int64`: The current lifecycle [`IterationStatus`](@ref) — `RUNNING` while the
  iteration is in flight, then `SUCCEEDED`, `FAILED`, or `KILLED` once it terminates.
- `error_message::String`: Captured exception text when `status_id` is `FAILED`. Empty
  otherwise.
"""
struct Iteration <: ResultType
    id::Int64
    experiment_id::Int64
    notes::String
    created_date::DateTime
    end_date::Optional{DateTime}
    parent_iteration_id::Optional{Int64}
    status_id::Int64
    error_message::String
end

struct IterationUpdatePayload <: UpsertType
    notes::Optional{String}
    end_date::Optional{DateTime}
    status_id::Optional{Int64}
    error_message::Optional{String}
end
