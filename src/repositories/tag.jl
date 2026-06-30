function fetch(::Type{<:Tag}, id::AbstractString)::Optional{Tag}
    tag = fetch(SQL_SELECT_TAG_BY_ID, (id=id,))
    return (isnothing(tag)) ? nothing : (Tag(tag))
end

# `value` is a string just like the UUID `id`, so the by-value lookup can no longer be a
# `fetch(Tag, ::AbstractString)` overload distinguished by argument type. It gets its own name.
function fetch_by_value(::Type{<:Tag}, value::AbstractString)::Optional{Tag}
    tag = fetch(SQL_SELECT_TAG_BY_VALUE, (value=value,))
    return (isnothing(tag)) ? nothing : (Tag(tag))
end

function fetch_tags(::Type{<:Project}, project_id::AbstractString)::Array{Tag,1}
    tags = fetch_all(SQL_SELECT_TAGS_BY_PROJECT_ID; parameters=(id=project_id,))
    return Tag.(tags)
end

function fetch_tags(::Type{<:Experiment}, experiment_id::AbstractString)::Array{Tag,1}
    tags = fetch_all(SQL_SELECT_TAGS_BY_EXPERIMENT_ID; parameters=(id=experiment_id,))
    return Tag.(tags)
end

function fetch_tags(::Type{<:Iteration}, iteration_id::AbstractString)::Array{Tag,1}
    tags = fetch_all(SQL_SELECT_TAGS_BY_ITERATION_ID; parameters=(id=iteration_id,))
    return Tag.(tags)
end

function _tag_id_by_value(tag_value::AbstractString)::String
    tag = fetch_by_value(Tag, tag_value)
    if isnothing(tag)
        # Insert the tag if absent; ignore the result and re-fetch to get the id.
        insert(Tag, tag_value)
        tag = fetch_by_value(Tag, tag_value)
    end
    return tag.id
end

function insert(
    ::Type{<:Tag}, value::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    return insert(SQL_INSERT_TAG, (value=value,))
end

function insert_tag(
    ::Type{<:Project}, project_id::AbstractString, tag_value::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    tag_id = _tag_id_by_value(tag_value)
    project_tag_fields = (project_id=project_id, tag_id=tag_id)
    return insert(SQL_INSERT_PROJECT_TAG, project_tag_fields)
end

function insert_tag(
    ::Type{<:Experiment}, experiment_id::AbstractString, tag_value::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    tag_id = _tag_id_by_value(tag_value)
    experiment_tag_fields = (experiment_id=experiment_id, tag_id=tag_id)
    return insert(SQL_INSERT_EXPERIMENT_TAG, experiment_tag_fields)
end

function insert_tag(
    ::Type{<:Iteration}, iteration_id::AbstractString, tag_value::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    tag_id = _tag_id_by_value(tag_value)
    iteration_tag_fields = (iteration_id=iteration_id, tag_id=tag_id)
    return insert(SQL_INSERT_ITERATION_TAG, iteration_tag_fields)
end

function delete(::Type{<:Tag}, id::AbstractString)::Bool
    return delete(SQL_DELETE_TAG, id)
end
