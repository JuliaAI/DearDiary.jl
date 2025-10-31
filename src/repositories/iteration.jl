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

function insert(
    ::Type{<:Iteration}, experiment_id::Integer
)::Tuple{Optional{<:Int64},UpsertResult}
    parameters = (
        experiment_id=experiment_id,
        created_date=(now() |> string),
    )
    return insert(SQL_INSERT_ITERATION, parameters)
end

function update(
    ::Type{<:Iteration}, id::Integer;
    notes::Optional{AbstractString}=nothing,
    end_date::Optional{DateTime}=nothing,
)::UpsertResult
    fields = (notes=notes, end_date=end_date)
    return update(SQL_UPDATE_ITERATION, fetch(Iteration, id); fields...)
end

delete(::Type{<:Iteration}, id::Integer)::Bool = delete(SQL_DELETE_ITERATION, id)
