function fetch(::Type{<:Iteration}, id::Integer)::Optional{Iteration}
    iteration = fetch(SQL_SELECT_ITERATION_BY_ID, (id=id,))
    return (isnothing(iteration)) ? nothing : (Iteration(iteration))
end

function fetch_all(::Type{<:Iteration}, experiment_id::Integer)::Array{Iteration,1}
    iterations = fetch_all(
        SQL_SELECT_ITERATIONS_BY_EXPERIMENT_ID; parameters=(id=experiment_id,)
    )
    return Iteration.(iterations)
end

function fetch_page(
    ::Type{<:Iteration}, experiment_id::Integer, page::Pagination
)::PaginatedResponse{Iteration}
    paged = fetch_page(
        SQL_SELECT_ITERATIONS_BY_EXPERIMENT_ID,
        SQL_COUNT_ITERATIONS_BY_EXPERIMENT_ID;
        parameters=(id=experiment_id,),
        page=page,
    )
    return PaginatedResponse{Iteration}(
        Iteration.(paged.rows), paged.total, page.limit, page.offset
    )
end

"""
    fetch_children(::Type{<:Iteration}, parent_id::Integer)::Array{Iteration,1}

Return the direct children of `parent_id` ordered by primary key ascending. Used by the
service layer's [`get_child_iterations`](@ref) to walk an HPO sweep or distributed-worker
fan-out one level at a time.
"""
function fetch_children(::Type{<:Iteration}, parent_id::Integer)::Array{Iteration,1}
    iterations = fetch_all(SQL_SELECT_ITERATIONS_BY_PARENT_ID; parameters=(id=parent_id,))
    return Iteration.(iterations)
end

function insert(
    ::Type{<:Iteration},
    experiment_id::Integer;
    parent_iteration_id::Optional{<:Integer}=nothing,
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    fields = (
        experiment_id=experiment_id,
        created_date=(string(now())),
        parent_iteration_id=parent_iteration_id,
        status_id=(Integer(RUNNING)),
    )
    return insert(SQL_INSERT_ITERATION, fields)
end

function update(
    ::Type{<:Iteration},
    id::Integer;
    notes::Optional{AbstractString}=nothing,
    end_date::Optional{DateTime}=nothing,
    status_id::Optional{<:Integer}=nothing,
    error_message::Optional{AbstractString}=nothing,
    julia_version::Optional{AbstractString}=nothing,
    git_sha::Optional{AbstractString}=nothing,
    git_dirty::Optional{<:Integer}=nothing,
    entrypoint::Optional{AbstractString}=nothing,
    project_toml::Optional{AbstractString}=nothing,
    manifest_toml::Optional{AbstractString}=nothing,
)::Type{<:UpsertResult}
    # The column is TEXT; stringify so the database stores ISO text instead of a
    # Julia-binary blob that a later version might not deserialize.
    end_date_text = (isnothing(end_date)) ? nothing : (string(end_date))
    fields = (
        notes=notes,
        end_date=end_date_text,
        status_id=status_id,
        error_message=error_message,
        julia_version=julia_version,
        git_sha=git_sha,
        git_dirty=git_dirty,
        entrypoint=entrypoint,
        project_toml=project_toml,
        manifest_toml=manifest_toml,
    )
    return update(SQL_UPDATE_ITERATION, fetch(Iteration, id); fields...)
end

delete(::Type{<:Iteration}, id::Integer)::Bool = delete(SQL_DELETE_ITERATION, id)

# Set `parent_iteration_id = NULL` on every child of `id`. DuckDB foreign keys have no
# `ON DELETE SET NULL` action and block deleting a still-referenced parent, so callers must
# run this before deleting a parent iteration to preserve historical lineage semantics.
function nullify_children(::Type{<:Iteration}, id::Integer)::Bool
    try
        DBInterface.execute(
            get_database(), duckdbify(SQL_NULLIFY_ITERATION_CHILDREN), (id=id,)
        )
        return true
    catch _
        return false
    end
end
