function fetch(::Type{<:Project}, id::Integer)::Optional{Project}
    project = fetch(SQL_SELECT_PROJECT_BY_ID, (id=id,))
    return (project |> isnothing) ? nothing : (project |> Project)
end

function fetch_all(::Type{<:Project})::Array{Project,1}
    return SQL_SELECT_PROJECTS |> fetch_all .|> Project
end

function insert(
    ::Type{<:Project}, name::AbstractString
)::Tuple{Optional{<:Int64},UpsertResult}
    return insert(SQL_INSERT_PROJECT, (name=name, created_date=(now() |> string)))
end

function update(
    ::Type{<:Project}, id::Integer;
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
)::UpsertResult
    fields = (name=name, description=description)
    return update(SQL_UPDATE_PROJECT, fetch(Project, id); fields...)
end

delete(::Type{<:Project}, id::Integer)::Bool = delete(SQL_DELETE_PROJECT, id)
