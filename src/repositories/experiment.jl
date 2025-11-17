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

function insert(
    ::Type{<:Experiment}, project_id::Integer, status_id::Integer, name::AbstractString
)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
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
)::UpsertResult
    fields = (status_id=status_id, name=name, description=description, end_date=end_date)
    return update(SQL_UPDATE_EXPERIMENT, fetch(Experiment, id); fields...)
end

delete(::Type{<:Experiment}, id::Integer)::Bool = delete(SQL_DELETE_EXPERIMENT, id)
