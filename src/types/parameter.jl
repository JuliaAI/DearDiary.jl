"""
    Parameter <: ResultType

A struct representing a parameter with its details.

Fields
- `id::Int64`: The ID of the parameter.
- `iteration_id::Int64`: The ID of the iteration this parameter belongs to.
- `key::String`: The key/name of the parameter.
- `value::String`: The value of the parameter.
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
    return Parameter(id, iteration_id, key, string(value))
end

struct ParameterCreatePayload <: UpsertType
    key::String
    value::String
end
function ParameterCreatePayload(key::AbstractString, value::Real)::ParameterCreatePayload
    return ParameterCreatePayload(key, string(value))
end

struct ParameterUpdatePayload <: UpsertType
    key::Optional{String}
    value::Optional{String}
end
function ParameterUpdatePayload(
    key::Optional{AbstractString}, value::Real
)::ParameterUpdatePayload
    return ParameterUpdatePayload(key, (string(value)))
end
