"""
    Parameter

A struct representing a parameter with its details.

Fields
- `id`: The ID of the parameter.
- `iteration_id`: The ID of the iteration this parameter belongs to.
- `key`: The key/name of the parameter.
- `value`: The value of the parameter.
"""
struct Parameter <: ResultType
    id::Int64
    iteration_id::Int64
    key::String
    value::String
end
function Parameter(
    id::Integer, iteration_id::Integer, key::AbstractString, value::Real
)::Parameter
    return Parameter(id, iteration_id, key, value |> string)
end

"""
    ParameterCreatePayload

A struct that represents the payload for creating a parameter.

Fields
- `key`: The key/name of the parameter.
- `value`: The value of the parameter.
"""
struct ParameterCreatePayload <: UpsertType
    key::String
    value::String
end
function ParameterCreatePayload(key::AbstractString, value::Real)::ParameterCreatePayload
    return ParameterCreatePayload(key, value |> string)
end

"""
    ParameterUpdatePayload

A struct that represents the payload for updating a parameter.

Fields
- `key`: The key/name of the parameter, or `nothing` if not updating.
- `value`: The value of the parameter, or `nothing` if not updating.
"""
struct ParameterUpdatePayload <: UpsertType
    key::Optional{String}
    value::Optional{String}
end
function ParameterUpdatePayload(
    key::Optional{AbstractString}, value::Optional{Real}
)::ParameterUpdatePayload
    return ParameterUpdatePayload(key, (value |> isnothing) ? nothing : (value |> string))
end
