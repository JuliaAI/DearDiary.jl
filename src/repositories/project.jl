function fetch(::Type{<:Project}, id::Integer)::Optional{Project}
    project = fetch(SQL_SELECT_PROJECT_BY_ID, (id=id,))
    return (isnothing(project)) ? nothing : (Project(project))
end

function fetch_all(::Type{<:Project})::Array{Project,1}
    return Project.(fetch_all(SQL_SELECT_PROJECTS))
end

function insert(
    ::Type{<:Project}, name::AbstractString
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    return insert(SQL_INSERT_PROJECT, (name=name, created_date=(string(now()))))
end

function update(
    ::Type{<:Project},
    id::Integer;
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
)::Type{<:UpsertResult}
    fields = (name=name, description=description)
    return update(SQL_UPDATE_PROJECT, fetch(Project, id); fields...)
end

delete(::Type{<:Project}, id::Integer)::Bool = delete(SQL_DELETE_PROJECT, id)
