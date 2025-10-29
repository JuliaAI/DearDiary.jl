const Optional{T} = Union{T,Nothing}

"""
    UpsertResult

A marker abstract type for the result of an upsert operation.
"""
abstract type UpsertResult end
"""
    Created

A marker type indicating that a record was successfully created.
"""
struct Created <: UpsertResult end

"""
    Updated

A marker type indicating that a record was successfully updated.
"""
struct Updated <: UpsertResult end

"""
    Duplicate

A marker type indicating that a record already exists.
"""
struct Duplicate <: UpsertResult end

"""
    Unprocessable

A marker type indicating that a record violates a constraint and cannot be processed.
"""
struct Unprocessable <: UpsertResult end

"""
    Error

A marker type indicating that an error occurred while creating or updating a record.
"""
struct Error <: UpsertResult end

"""
    ResultType

A marker abstract type for result types.
"""
abstract type ResultType end

"""
    UpsertType

A marker abstract type for upsert types.
"""
abstract type UpsertType end

abstract type KeyConversionTrait end
struct WithSymbolKeys <: KeyConversionTrait end
struct WithStringKeys <: KeyConversionTrait end

function KeyConversionTrait(::Type{Dict{K,Any}}) where {K}
    throw(ArgumentError("Unsupported key type $K. Supported types are Symbol and String."))
end
KeyConversionTrait(::Type{Dict{Symbol,Any}}) = WithSymbolKeys()
KeyConversionTrait(::Type{Dict{String,Any}}) = WithStringKeys()

convert_field_to_key(::WithSymbolKeys, field::Symbol) = field
convert_field_to_key(::WithStringKeys, field::Symbol) = field |> String

"""
    type_from_dict(::Type{T}, data::Dict{K,Any}, trait::KeyConversionTrait)::T where {T, K}

Builds an instance of type `T` from a dictionary `data` with `trait` related to the type `K`. All the fields in the struct `T` must be present in the dictionary.
"""
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

# Allowing construction of ResultType from Dict
function (::Type{T})(data::Dict{K,Any})::T where {T<:ResultType,K} 
    return type_from_dict(T, data, (data |> typeof |> KeyConversionTrait))
end
