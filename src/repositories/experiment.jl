function fetch(::Type{<:Experiment}, id::Integer)::Optional{Experiment}
    experiment = fetch(SQL_SELECT_EXPERIMENT_BY_ID, (id=id,))
    return (experiment |> isnothing) ? nothing : (experiment |> Experiment)
end

function fetch_all(::Type{<:Experiment}, project_id::Integer)::Array{Experiment,1}
    experiments = fetch_all(
        SQL_SELECT_EXPERIMENTS_BY_PROJECT_ID;
        parameters=(id=project_id,),
    )
    return experiments .|> Experiment
end

function fetch_page(
    ::Type{<:Experiment}, project_id::Integer, page::Pagination,
)::PaginatedResponse{Experiment}
    paged = fetch_page(
        SQL_SELECT_EXPERIMENTS_BY_PROJECT_ID,
        SQL_COUNT_EXPERIMENTS_BY_PROJECT_ID;
        parameters=(id=project_id,), page=page,
    )
    return PaginatedResponse{Experiment}(
        paged.rows .|> Experiment, paged.total, page.limit, page.offset,
    )
end

function insert(
    ::Type{<:Experiment}, project_id::Integer, status_id::Integer, name::AbstractString
)::@NamedTuple{id::Optional{<:Int64}, status::DataType}
    fields = (
        project_id=project_id,
        status_id=status_id,
        name=name,
        created_date=(now() |> string),
    )
    return insert(SQL_INSERT_EXPERIMENT, fields)
end

function update(
    ::Type{<:Experiment}, id::Integer;
    status_id::Optional{Integer}=nothing,
    name::Optional{AbstractString}=nothing,
    description::Optional{String}=nothing,
    end_date::Optional{DateTime}=nothing,
    clear_end_date::Bool=false,
)::Type{<:UpsertResult}
    # The column is TEXT — stringify so SQLite stores ISO text instead of a
    # Julia-binary blob (which `sqldeserialize` can't read across versions).
    # `clear_end_date=true` writes an empty string, which is how the row marks
    # "no end date" (the column default) and is round-tripped to `nothing` by
    # `type_from_dict`. It takes precedence over an explicit `end_date` value.
    end_date_text = if clear_end_date
        ""
    elseif end_date |> isnothing
        nothing
    else
        end_date |> string
    end
    fields = (
        status_id=status_id, name=name, description=description, end_date=end_date_text,
    )
    return update(SQL_UPDATE_EXPERIMENT, fetch(Experiment, id); fields...)
end

delete(::Type{<:Experiment}, id::Integer)::Bool = delete(SQL_DELETE_EXPERIMENT, id)
