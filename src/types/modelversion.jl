"""
    ModelVersion <: ResultType

A struct representing a concrete checkpoint of a registered [`Model`](@ref). Each version is
produced by a specific [`Iteration`](@ref) and may point at an artifact [`Resource`](@ref)
that stores the serialised bytes.

Fields
- `id::String`: The unique identifier of the model version.
- `model_id::String`: The identifier of the parent [`Model`](@ref).
- `version::Int64`: The per-model monotonically-increasing version number, assigned by the
  service layer at registration time.
- `iteration_id::String`: The identifier of the [`Iteration`](@ref) that produced this
  checkpoint, recording lineage from training run to registered artifact.
- `resource_id::Optional{String}`: The identifier of the [`Resource`](@ref) that holds the
  serialised artifact, or `nothing` when the registration predates the upload.
- `stage_id::Int64`: The lifecycle [`Stage`](@ref) the version currently occupies.
- `description::String`: A free-form description of the version (e.g. training notes).
- `created_date::DateTime`: The date and time when the version was registered.
- `updated_date::Optional{DateTime}`: The date and time of the most recent update, or
  `nothing` if the record has never been updated.
"""
struct ModelVersion <: ResultType
    id::String
    model_id::String
    version::Int64
    iteration_id::String
    resource_id::Optional{String}
    stage_id::Int64
    description::String
    created_date::DateTime
    updated_date::Optional{DateTime}
end

struct ModelVersionCreatePayload <: UpsertType
    iteration_id::String
    resource_id::Optional{String}
    description::Optional{String}
end

struct ModelVersionUpdatePayload <: UpsertType
    stage_id::Optional{Int64}
    description::Optional{String}
    resource_id::Optional{String}
end
