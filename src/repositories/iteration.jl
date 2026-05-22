function fetch(::Type{<:Iteration}, id::Integer)::Optional{Iteration}
    iteration = fetch(SQL_SELECT_ITERATION_BY_ID, (id=id,))
    return (iteration |> isnothing) ? nothing : (iteration |> Iteration)
end

function fetch_all(::Type{<:Iteration}, experiment_id::Integer)::Array{Iteration,1}
    iterations = fetch_all(
        SQL_SELECT_ITERATIONS_BY_EXPERIMENT_ID;
        parameters=(id=experiment_id,),
    )
    return iterations .|> Iteration
end

function fetch_page(
    ::Type{<:Iteration}, experiment_id::Integer, page::Pagination,
)::PaginatedResponse{Iteration}
    paged = fetch_page(
        SQL_SELECT_ITERATIONS_BY_EXPERIMENT_ID,
        SQL_COUNT_ITERATIONS_BY_EXPERIMENT_ID;
        parameters=(id=experiment_id,), page=page,
    )
    return PaginatedResponse{Iteration}(
        paged.rows .|> Iteration, paged.total, page.limit, page.offset,
    )
end

"""
    fetch_children(::Type{<:Iteration}, parent_id::Integer)::Array{Iteration,1}

Return the direct children of `parent_id` ordered by primary key ascending. Used by the
service layer's [`get_child_iterations`](@ref) to walk an HPO sweep or distributed-worker
fan-out one level at a time.
"""
function fetch_children(::Type{<:Iteration}, parent_id::Integer)::Array{Iteration,1}
    iterations = fetch_all(
        SQL_SELECT_ITERATIONS_BY_PARENT_ID;
        parameters=(id=parent_id,),
    )
    return iterations .|> Iteration
end

function insert(
    ::Type{<:Iteration}, experiment_id::Integer;
    parent_iteration_id::Optional{<:Integer}=nothing,
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    fields = (
        experiment_id=experiment_id,
        created_date=(now() |> string),
        parent_iteration_id=parent_iteration_id,
        status_id=(RUNNING |> Integer),
    )
    return insert(SQL_INSERT_ITERATION, fields)
end

function update(
    ::Type{<:Iteration}, id::Integer;
    notes::Optional{AbstractString}=nothing,
    end_date::Optional{DateTime}=nothing,
    status_id::Optional{<:Integer}=nothing,
    error_message::Optional{AbstractString}=nothing,
)::Type{<:UpsertResult}
    # The column is TEXT — stringify so SQLite stores ISO text instead of a
    # Julia-binary blob (which `sqldeserialize` can't read across versions).
    end_date_text = (end_date |> isnothing) ? nothing : (end_date |> string)
    fields = (
        notes=notes,
        end_date=end_date_text,
        status_id=status_id,
        error_message=error_message,
    )
    return update(SQL_UPDATE_ITERATION, fetch(Iteration, id); fields...)
end

delete(::Type{<:Iteration}, id::Integer)::Bool = delete(SQL_DELETE_ITERATION, id)
