function fetch(::Type{<:Model}, id::Integer)::Optional{Model}
    model = fetch(SQL_SELECT_MODEL_BY_ID, (id=id,))
    return (isnothing(model)) ? nothing : (Model(model))
end

function fetch_all(::Type{<:Model}, project_id::Integer)::Array{Model,1}
    models = fetch_all(SQL_SELECT_MODELS_BY_PROJECT_ID; parameters=(id=project_id,))
    return Model.(models)
end

function fetch_page(
    ::Type{<:Model}, project_id::Integer, page::Pagination
)::PaginatedResponse{Model}
    paged = fetch_page(
        SQL_SELECT_MODELS_BY_PROJECT_ID,
        SQL_COUNT_MODELS_BY_PROJECT_ID;
        parameters=(id=project_id,),
        page=page,
    )
    return PaginatedResponse{Model}(
        Model.(paged.rows), paged.total, page.limit, page.offset
    )
end

function insert(
    ::Type{<:Model}, project_id::Integer, name::AbstractString
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    fields = (project_id=project_id, name=name, created_date=(string(now())))
    return insert(SQL_INSERT_MODEL, fields)
end

function update(
    ::Type{<:Model},
    id::Integer;
    name::Optional{AbstractString}=nothing,
    description::Optional{AbstractString}=nothing,
)::Type{<:UpsertResult}
    fields = (name=name, description=description, updated_date=(string(now())))
    return update(SQL_UPDATE_MODEL, fetch(Model, id); fields...)
end

delete(::Type{<:Model}, id::Integer)::Bool = delete(SQL_DELETE_MODEL, id)
