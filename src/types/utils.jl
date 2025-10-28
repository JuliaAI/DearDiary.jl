const Optional{T} = Union{T,Nothing}

abstract type ResultType end
abstract type UpsertType end

abstract type KeyConversionTrait end
struct WithSymbolKeys <: KeyConversionTrait end
struct WithStringKeys <: KeyConversionTrait end

function KeyConversionTrait(::Type{Dict{K,Any}}) where {K}
    throw(ArgumentError("Unsupported key type $K. Supported types are Symbol and String."))
end
KeyConversionTrait(::Type{Dict{Symbol,Any}}) = WithSymbolKeys()
KeyConversionTrait(::Type{Dict{String,Any}}) = WithStringKeys()

Base.convert(::Type{Status}, value::Integer) = Status(value)

convert_field_to_key(::WithSymbolKeys, field::Symbol) = field
convert_field_to_key(::WithStringKeys, field::Symbol) = field |> String

function type_from_dict(
    ::Type{T}, data::Dict{K,Any}, trait::KeyConversionTrait
)::T where {T,K}
    type_fields = T |> fieldnames
    values = map(type_fields) do field
        key = convert_field_to_key(trait, field)
        value = get(data, key, nothing)
        if value === nothing
            throw(KeyError(key))
        end

        field_type = fieldtype(T, field)

        if value isa field_type
            return value
        end

        if DateTime <: field_type && !(value isa DateTime)
            try
                if Nothing <: field_type && isempty(value)
                    return nothing
                end
                return value |> DateTime
            catch e
                throw(ArgumentError("Cannot convert value '$value' to DateTime for field $field: $e"))
            end
        end

        try
            return convert(field_type, value)
        catch e
            throw(ArgumentError("Cannot convert value '$value' ($(typeof(value))) to $(field_type) for field $field: $e"))
        end
    end
    return T(values...)
end

"""
    type_from_dict(::Type{T}, data::Dict{K,Any})::T where {T, K}

Builds an instance of type `T` from a dictionary `data`. All fields of the struct `T` must be present in the dictionary. If a field is of type `DateTime` and the corresponding value in the dictionary is not a `DateTime`, it will be converted to it.

# Arguments
- `::Type{T}`: The type of the struct to create.
- `data::Dict{K,Any}`: The dictionary containing the data to populate the struct.

# Returns
An instance of type `T` populated with the values from the dictionary.
"""
function type_from_dict(::Type{T}, data::Dict{K,Any})::T where {T,K}
    return type_from_dict(T, data, (data |> typeof |> KeyConversionTrait))
end

# Allowing construction of ResultType from Dict
(::Type{T})(data::Dict{K,Any}) where {T<:ResultType,K} = type_from_dict(T, data)
