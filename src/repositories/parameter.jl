function fetch(::Type{<:Parameter}, id::Integer)::Optional{Parameter}
    parameter = fetch(SQL_SELECT_PARAMETER_BY_ID, (id=id,))
    return (parameter |> isnothing) ? nothing : (parameter |> Parameter)
end

function fetch_all(::Type{<:Parameter}, iteration_id::Integer)::Array{Parameter,1}
    parameters = fetch_all(
        SQL_SELECT_PARAMETERS_BY_ITERATION_ID;
        parameters=(id=iteration_id,),
    )
    return parameters .|> Parameter
end

function insert(
    ::Type{<:Parameter}, iteration_id::Integer, key::AbstractString, value::AbstractString
)::@NamedTuple{id::Optional{<:Int64},status::UpsertResult}
    fields = (
        iteration_id=iteration_id,
        key=key,
        value=value,
        created_date=(now() |> string),
    )
    return insert(SQL_INSERT_PARAMETER, fields)
end

function update(
    ::Type{<:Parameter}, id::Integer;
    key::Optional{AbstractString}=nothing,
    value::Optional{AbstractString}=nothing,
)::UpsertResult
    fields = (key=key, value=value)
    return update(SQL_UPDATE_PARAMETER, fetch(Parameter, id); fields...)
end

delete(::Type{<:Parameter}, id::Integer)::Bool = delete(SQL_DELETE_PARAMETER, id)

function delete(::Type{<:Parameter}, iteration::Iteration)::Bool
    return delete(SQL_DELETE_PARAMETERS_BY_ITERATION_ID, iteration.id)
end
