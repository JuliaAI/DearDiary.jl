const _PREVIEW_LENGTH = 60

_short_id(id::AbstractString)::String = length(id) > 8 ? first(id, 8) * "…" : String(id)

function _enum_label(::Type{E}, value::Integer)::String where {E<:Enum}
    return value in Integer.(instances(E)) ? string(E(value)) : string(value)
end

# The first line of a string, cut to a preview length, plus the line count when there is
# more than one. Keeps a Manifest.toml or a stack trace from flooding the REPL.
function _preview(text::AbstractString)::String
    lines = split(chomp(text), '\n')
    head = first(lines)
    if length(head) > _PREVIEW_LENGTH
        head = first(head, _PREVIEW_LENGTH - 1) * "…"
    end
    preview = repr(String(head))
    return length(lines) > 1 ? "$(preview) ($(length(lines)) lines)" : preview
end

_field_repr(value) = repr(value)
_field_repr(value::AbstractString) = _preview(value)
_field_repr(value::DateTime) = string(value)
_field_repr(value::AbstractVector{UInt8}) = _format_bytes(length(value))

_hidden_fields(::Type{<:ResultType}) = ()
_hidden_fields(::Type{User}) = (:password,)

_enum_fields(::Type{<:ResultType}) = (;)
_enum_fields(::Type{Experiment}) = (status_id=ExperimentStatus,)
_enum_fields(::Type{Iteration}) = (status_id=IterationStatus,)
_enum_fields(::Type{ModelVersion}) = (stage_id=Stage,)

function _summary(::IO, x::ResultType)::String
    return hasfield(typeof(x), :id) ? _short_id(string(getfield(x, :id))) : ""
end
function _summary(::IO, x::Union{User,UserResponse})::String
    return x.is_admin ? "$(repr(x.username)), admin" : repr(x.username)
end
_summary(::IO, x::Project)::String = repr(x.name)
function _summary(::IO, x::UserPermission)::String
    flags = (
        ("create", x.create_permission),
        ("read", x.read_permission),
        ("update", x.update_permission),
        ("delete", x.delete_permission),
    )
    granted = [action for (action, allowed) in flags if allowed]
    return isempty(granted) ? "no access" : join(granted, ", ")
end
function _summary(::IO, x::Experiment)::String
    return "$(repr(x.name)), $(_enum_label(ExperimentStatus, x.status_id))"
end
function _summary(::IO, x::Iteration)::String
    return "$(_short_id(x.id)), $(_enum_label(IterationStatus, x.status_id))"
end
_summary(::IO, x::Parameter)::String = "$(x.key) = $(repr(x.value))"
function _summary(io::IO, x::Metric)::String
    return "$(x.key) = $(sprint(show, x.value; context=io)), step = $(x.step)"
end
function _summary(::IO, x::Resource)::String
    return "$(repr(x.name)), $(x.backend), $(_format_bytes(x.size_bytes))"
end
_summary(::IO, x::Tag)::String = repr(x.value)
_summary(::IO, x::Model)::String = repr(x.name)
_summary(::IO, x::ModelVersion)::String = "$(x.version), $(_enum_label(Stage, x.stage_id))"
function _summary(::IO, x::PaginatedResponse)::String
    return "$(length(x.data)) of $(x.total), offset $(x.offset)"
end

"""
    Base.show(io::IO, x::ResultType)

Print a [`ResultType`](@ref) on one line, such as `Metric(loss = 0.5, step = 1)`. Julia
uses this form for records inside vectors and dictionaries, in `print`, and in string
interpolation, so a vector of records lists one record per line and is trimmed to the
terminal like any other vector.
"""
function Base.show(io::IO, x::ResultType)
    return print(io, nameof(typeof(x)), "(", _summary(io, x), ")")
end

"""
    Base.show(io::IO, ::MIME"text/plain", x::T) where {T<:ResultType}

Print a [`ResultType`](@ref) as its one-line form followed by its fields, aligned in two
columns. Status and stage ids carry their enum name, long or multi-line text is cut to its
first line, byte arrays show their size, and the [`User`](@ref) password hash is left out.
"""
function Base.show(io::IO, ::MIME"text/plain", x::T) where {T<:ResultType}
    show(io, x)
    names = [name for name in fieldnames(T) if !(name in _hidden_fields(T))]
    isempty(names) && return nothing
    width = maximum(name -> length(string(name)), names)
    enums = _enum_fields(T)
    for name in names
        value = getfield(x, name)
        text = if haskey(enums, name)
            "$(value) ($(_enum_label(enums[name], value)))"
        else
            _field_repr(value)
        end
        print(io, "\n  ", rpad(string(name), width), "  ", text)
    end
    return nothing
end

function Base.show(io::IO, ::MIME"text/plain", x::PaginatedResponse)
    show(io, x)
    for record in x.data
        print(io, "\n  ")
        show(io, record)
    end
    return nothing
end

# Base prints this `NamedTuple` through its constructor, because the declared `id` type is
# wider than the value's. The create functions return it, so print it as a literal.
function Base.show(
    io::IO, ::MIME"text/plain", x::@NamedTuple{id::Optional{String}, status::DataType}
)
    return print(io, "(id = ", repr(x.id), ", status = ", x.status, ")")
end

# A vector of records is a Tables.jl row table, so `DataFrame(get_metrics(id))` and
# `pretty_table(get_metrics(id))` work without DearDiary depending on either package.
Tables.istable(::Type{<:AbstractVector{<:ResultType}}) = true
Tables.rowaccess(::Type{<:AbstractVector{<:ResultType}}) = true
Tables.rows(x::AbstractVector{<:ResultType}) = x
function Tables.schema(::AbstractVector{T}) where {T<:ResultType}
    return isconcretetype(T) ? Tables.Schema(fieldnames(T), fieldtypes(T)) : nothing
end
