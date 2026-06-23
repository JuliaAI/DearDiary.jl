"""
    Base.Dict(object::UpsertType)::Dict{String,Any}

Transforms a [`ResultType`](@ref) or an [`UpsertType`](@ref) object to a dictionary.

# Arguments
- `object::Union{ResultType,UpsertType}`: The object to convert.

# Returns
A dictionary representation of the object.
"""
function Base.Dict(object::Union{ResultType,UpsertType})::Dict{Symbol,Any}
    fields = fieldnames(typeof(object))
    values = [getfield(object, field) for field in fields]
    return Dict(collect(zip(fields, values)))
end

"""
    compare_object_fields(object::ResultType; kwargs...)::Bool

Checks if the object fields are different from the provided keyword arguments.

# Arguments
- `object::ResultType`: The object to check.
- `kwargs...`: The keyword arguments to compare with the object fields.

# Returns
`true` if any of the object fields are different from the provided keyword arguments, `false` otherwise.
"""
function compare_object_fields(object::ResultType; kwargs...)::Bool
    fields = fieldnames(typeof(object))
    for field in fields
        if haskey(kwargs, field)
            if getfield(object, field) != kwargs[field]
                return true
            end
        end
    end
    return false
end
