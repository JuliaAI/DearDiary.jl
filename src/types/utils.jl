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
    Updated <: UpsertResult

A marker type indicating that a record was successfully updated.
"""
struct Updated <: UpsertResult end

"""
    Duplicate <: UpsertResult

A marker type indicating that a record already exists.
"""
struct Duplicate <: UpsertResult end

"""
    Unprocessable <: UpsertResult

A marker type indicating that a record violates a constraint and cannot be processed.
"""
struct Unprocessable <: UpsertResult end

"""
    Error <: UpsertResult

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

"""
    Pagination

Cursor for windowing a collection of records.

Fields
- `limit::Int64`: Maximum number of records to return (capped at the route boundary).
- `offset::Int64`: Number of records to skip before the page starts.
"""
struct Pagination
    limit::Int64
    offset::Int64
end

"""
    PaginatedResponse{T} <: ResultType

Envelope returned by paginated list endpoints.

Fields
- `data::Array{T,1}`: The records in this page.
- `total::Int64`: Total number of matching records (across all pages).
- `limit::Int64`: The page size used.
- `offset::Int64`: The offset used.
"""
struct PaginatedResponse{T} <: ResultType
    data::Array{T,1}
    total::Int64
    limit::Int64
    offset::Int64
end

abstract type KeyConversionTrait end
struct WithSymbolKeys <: KeyConversionTrait end
struct WithStringKeys <: KeyConversionTrait end

function KeyConversionTrait(::Type{D}) where {D<:AbstractDict}
    K = keytype(D)
    message = "missy Unsupported key type $K. Supported types are Symbol and String."
    throw(ArgumentError(message))
end
KeyConversionTrait(::Type{D}) where {D<:AbstractDict{Symbol,Any}} = WithSymbolKeys()
KeyConversionTrait(::Type{D}) where {D<:AbstractDict{String,Any}} = WithStringKeys()

convert_field_to_key(::WithSymbolKeys, field::Symbol) = field
convert_field_to_key(::WithStringKeys, field::Symbol) = String(field)

"""
    type_from_dict(::Type{T}, data::AbstractDict)::T where {T}

Build an instance of `T` from `data`, whose keys may be `Symbol`s or `String`s. Missing keys
and `missing` values become `nothing` for fields that allow it. Every other value is
converted to the field type, and an `ArgumentError` is thrown when that conversion fails.
"""
function type_from_dict(::Type{T}, data::AbstractDict)::T where {T}
    type_fields = fieldnames(T)
    values = map(type_fields) do field
        key = convert_field_to_key((KeyConversionTrait(typeof(data))), field)
        value = haskey(data, key) ? data[key] : nothing

        field_type = fieldtype(T, field)

        if isnothing(value) && Nothing <: field_type
            return nothing
        end

        # The database driver hands back `missing` for NULL columns; treat it the same as
        # `nothing` when the destination field allows it. Without this branch a
        # nullable VARCHAR column (e.g. `model_version.resource_id`) would fail to
        # `convert(::Type{Union{Nothing,String}}, missing)` on every fetch.
        if value isa Missing && Nothing <: field_type
            return nothing
        end

        if value isa field_type
            return value
        end

        if DateTime <: field_type && !(value isa DateTime)
            try
                if Nothing <: field_type && (isempty(value))
                    return nothing
                end
                return DateTime(value)
            catch e
                throw(
                    ArgumentError(
                        "Cannot convert value '$value' to DateTime for field $field: $e"
                    ),
                )
            end
        end

        try
            return convert(field_type, value)
        catch e
            throw(
                ArgumentError(
                    "Cannot convert value '$value' ($(value |> typeof)) to $(field_type) for field $field: $e",
                ),
            )
        end
    end
    return T(values...)
end

# Allow construction of ResultType from Dict
(::Type{T})(data::AbstractDict) where {T<:ResultType} = type_from_dict(T, data)
