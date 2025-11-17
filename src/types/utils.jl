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

abstract type KeyConversionTrait end
struct WithSymbolKeys <: KeyConversionTrait end
struct WithStringKeys <: KeyConversionTrait end

function KeyConversionTrait(::Type{D}) where {D<:AbstractDict}
    K = D |> keytype
    message = "missy Unsupported key type $K. Supported types are Symbol and String."
    throw(ArgumentError(message))
end
KeyConversionTrait(::Type{D}) where {D<:AbstractDict{Symbol,Any}} = WithSymbolKeys()
KeyConversionTrait(::Type{D}) where {D<:AbstractDict{String,Any}} = WithStringKeys()

convert_field_to_key(::WithSymbolKeys, field::Symbol) = field
convert_field_to_key(::WithStringKeys, field::Symbol) = field |> String

"""
    type_from_dict(::Type{T}, data::Dict{K,Any}, trait::KeyConversionTrait)::T where {T, K}

Builds an instance of type `T` from a dictionary `data` with `trait` related to the type `K`. All the fields in the struct `T` must be present in the dictionary.
"""
function type_from_dict(::Type{T}, data::AbstractDict)::T where {T}
    type_fields = T |> fieldnames
    values = map(type_fields) do field
        key = convert_field_to_key((data |> typeof |> KeyConversionTrait), field)
        value = haskey(data, key) ? data[key] : nothing

        field_type = fieldtype(T, field)

        if value |> isnothing && Nothing <: field_type
            return nothing
        end

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
(::Type{T})(data::AbstractDict) where {T<:ResultType} = type_from_dict(T, data)

"""
    Base.show(io::IO, ::MIME"text/plain", T::Type{<:UpsertResult})

Show a pretty-printed representation of an [`UpsertResult`](@ref) type.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for plain text.
- `x::T`: The upsert result type to show.

# Returns
Nothing, but prints the representation to the IO stream.
"""
function Base.show(io::IO, ::MIME"text/plain", x::T) where {T<:ResultType}
    println(io, T)
    fields = T |> fieldnames
    for (i, name) in (fields |> enumerate)
        prefix = i < (fields |> length) ? " ├ " : " └ "
        value = getfield(x, name)
        value_repr = if value isa DateTime
            value |> string
        elseif value isa Array{UInt8,1} && (value |> length) > 6
            compressed_array_repr = [
                (value[1:3] .|> repr)...,
                "…",
                (value[end-2:end] .|> repr)...,
            ]
            "UInt8[$(join(compressed_array_repr, ", "))]"
        else
            value |> repr
        end
        print(io, prefix, "$(name) = $(value_repr)", i < (fields |> length) ? "\n" : "")
    end
end

"""
    Base.show(io::IO, ::MIME"text/plain", x::Array{T,1}) where {T<:ResultType}

Show a pretty-printed representation of an array of [`ResultType`](@ref) types.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for plain text.
- `x::Array{T,1}`: The array of result types to show.

# Returns
Nothing, but prints the representation to the IO stream.
"""
function Base.show(io::IO, ::MIME"text/plain", x::AbstractArray{T,1}) where {T<:ResultType}
    n = x |> length
    println(io, "$(n)-element Vector{$(T)}:")
    if n <= 6
        for (i, x) in (x |> enumerate)
            show(io, MIME"text/plain"(), x)
            if i < n
                io |> println
            end
        end
    else
        for i in 1:3
            show(io, MIME"text/plain"(), x[i])
            io |> println
        end
        io |> println
        println(io, "  ⋮")
        io |> println
        for i in (n-2):n
            show(io, MIME"text/plain"(), x[i])
            if i < n
                io |> println
            end
        end
    end
end

function Base.show(
    io::IO, ::MIME"text/plain", x::NamedTuple{(:id, :status),T}
) where {T<:Tuple{Optional{<:Int64},UpsertResult}}
    print(io, "(id = $(x.id), status = $(x.status))")
end
