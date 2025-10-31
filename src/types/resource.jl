"""
    Resource

A struct representing a resource associated with an experiment.

Fields
- `id`: The ID of the resource.
- `experiment_id`: The ID of the experiment this resource belongs to.
- `name`: The name of the resource.
- `description`: A description of the resource.
- `data`: The binary data of the resource.
- `created_date`: The date and time when the resource was created.
- `updated_date`: The date and time when the resource was last updated.
"""
struct Resource <: ResultType
    id::Int64
    experiment_id::Int64
    name::String
    description::String
    data::Optional{Array{UInt8,1}}
    created_date::DateTime
    updated_date::Optional{DateTime}
end
