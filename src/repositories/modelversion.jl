function fetch(::Type{<:ModelVersion}, id::Integer)::Optional{ModelVersion}
    version = fetch(SQL_SELECT_MODELVERSION_BY_ID, (id=id,))
    return (isnothing(version)) ? nothing : (ModelVersion(version))
end

function fetch_all(::Type{<:ModelVersion}, model_id::Integer)::Array{ModelVersion,1}
    versions = fetch_all(SQL_SELECT_MODELVERSIONS_BY_MODEL_ID; parameters=(id=model_id,))
    return ModelVersion.(versions)
end

function fetch_page(
    ::Type{<:ModelVersion}, model_id::Integer, page::Pagination
)::PaginatedResponse{ModelVersion}
    paged = fetch_page(
        SQL_SELECT_MODELVERSIONS_BY_MODEL_ID,
        SQL_COUNT_MODELVERSIONS_BY_MODEL_ID;
        parameters=(id=model_id,),
        page=page,
    )
    return PaginatedResponse{ModelVersion}(
        ModelVersion.(paged.rows), paged.total, page.limit, page.offset
    )
end

function insert(
    ::Type{<:ModelVersion},
    model_id::Integer,
    iteration_id::Integer,
    resource_id::Optional{<:Integer},
    stage_id::Integer,
    description::AbstractString,
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    fields = (
        model_id=model_id,
        iteration_id=iteration_id,
        resource_id=resource_id,
        stage_id=stage_id,
        description=description,
        created_date=(string(now())),
    )
    return insert(SQL_INSERT_MODELVERSION, fields)
end

function update(
    ::Type{<:ModelVersion},
    id::Integer;
    stage_id::Optional{Integer}=nothing,
    description::Optional{AbstractString}=nothing,
    resource_id::Optional{Integer}=nothing,
)::Type{<:UpsertResult}
    fields = (
        stage_id=stage_id,
        description=description,
        resource_id=resource_id,
        updated_date=(string(now())),
    )
    return update(SQL_UPDATE_MODELVERSION, fetch(ModelVersion, id); fields...)
end

delete(::Type{<:ModelVersion}, id::Integer)::Bool = delete(SQL_DELETE_MODELVERSION, id)

"""
    delete_all(::Type{<:ModelVersion}, model_id::Integer)::Bool

Delete every [`ModelVersion`](@ref) under `model_id` in a single statement. Used by the
service-layer cascade when a [`Model`](@ref) is deleted.
"""
function delete_all(::Type{<:ModelVersion}, model_id::Integer)::Bool
    try
        DBInterface.execute(
            get_database(), duckdbify(SQL_DELETE_MODELVERSIONS_BY_MODEL_ID), (id=model_id,)
        )
        return true
    catch _
        return false
    end
end

"""
    archive_production_siblings(model_id::Integer, excluded_id::Integer)::Bool

Demote every [`ModelVersion`](@ref) under `model_id` that currently holds [`PRODUCTION`](@ref)
to [`ARCHIVED`](@ref), skipping `excluded_id`. The service layer calls this immediately after
promoting a new version to `PRODUCTION` to restore the "at most one production version per
model" invariant.
"""
function archive_production_siblings(model_id::Integer, excluded_id::Integer)::Bool
    try
        DBInterface.execute(
            get_database(),
            duckdbify(SQL_ARCHIVE_PRODUCTION_SIBLINGS),
            (
                model_id=model_id,
                production_stage=(Integer(PRODUCTION)),
                archived_stage=(Integer(ARCHIVED)),
                excluded_id=excluded_id,
                updated_date=(string(now())),
            ),
        )
        return true
    catch _
        return false
    end
end
