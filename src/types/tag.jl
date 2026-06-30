"""
    Tag <: ResultType

A struct that represents a tag.

Fields
- `id::String`: The ID of the tag.
- `value::String`: The value of the tag.
"""
struct Tag <: ResultType
    id::String
    value::String
end

struct TagCreatePayload <: UpsertType
    value::String
end
