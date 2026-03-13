"""
    Tag <: ResultType

A struct that represents a tag.

Fields
- `id::Int64`: The ID of the tag.
- `value::String`: The value of the tag.
"""
struct Tag <: ResultType
    id::Int64
    value::String
end

struct TagCreatePayload <: UpsertType
    value::String
end
