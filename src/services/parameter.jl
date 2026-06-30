"""
    get_parameter(id::AbstractString)::Optional{Parameter}

Get a [`Parameter`](@ref) by id.

# Arguments
- `id::AbstractString`: The id of the parameter to query.

# Returns
A [`Parameter`](@ref) object. If the record does not exist, return `nothing`.
"""
get_parameter(id::AbstractString)::Optional{Parameter} = fetch(Parameter, id)

"""
    get_parameters(iteration_id::AbstractString)::Array{Parameter, 1}

Get all [`Parameter`](@ref) for a given iteration.

# Arguments
- `iteration_id::AbstractString`: The id of the iteration to query.

# Returns
An array of [`Parameter`](@ref) objects.
"""
function get_parameters(iteration_id::AbstractString)::Array{Parameter,1}
    return fetch_all(Parameter, iteration_id)
end

"""
    get_parameters(iteration_id::AbstractString, page::Pagination)::PaginatedResponse{Parameter}

Get a page of [`Parameter`](@ref) records for an iteration, with `total` count populated.

# Arguments
- `iteration_id::AbstractString`: The id of the iteration to query.
- `page::Pagination`: The page bounds (limit + offset).

# Returns
A [`PaginatedResponse`](@ref) of `Parameter`.
"""
function get_parameters(
    iteration_id::AbstractString, page::Pagination
)::PaginatedResponse{Parameter}
    return fetch_page(Parameter, iteration_id, page)
end

"""
    create_parameter(iteration_id::AbstractString, key::AbstractString, value::AbstractString)::NamedTuple{id::Optional{String},status::DataType}

Create a [`Parameter`](@ref).

# Arguments
- `iteration_id::AbstractString`: The id of the iteration to create the parameter for.
- `key::AbstractString`: The key of the parameter.
- `value::AbstractString`: The value of the parameter.

# Returns
- The created parameter ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_parameter(
    iteration_id::AbstractString, key::AbstractString, value::AbstractString
)::@NamedTuple{id::Optional{String}, status::DataType}
    iteration = get_iteration(iteration_id)
    if isnothing(iteration)
        return (id=nothing, status=Unprocessable)
    end

    # Ended iterations are immutable.
    if !(isnothing(iteration.end_date))
        return (id=nothing, status=Unprocessable)
    end

    parameter_id, parameter_upsert_result = insert(Parameter, iteration_id, key, value)
    if !(parameter_upsert_result === Created)
        return (id=nothing, status=parameter_upsert_result)
    end
    return (id=parameter_id, status=parameter_upsert_result)
end

"""
    create_parameter(iteration_id::AbstractString, key::AbstractString, value::Real)::NamedTuple{id::Optional{String},status::DataType}

Create a [`Parameter`](@ref).

# Arguments
- `iteration_id::AbstractString`: The id of the iteration to create the parameter for.
- `key::AbstractString`: The key of the parameter.
- `value::Real`: The value of the parameter.

# Returns
- The created parameter ID. If an error occurs, `nothing` is returned.
- An [`UpsertResult`](@ref). [`Created`](@ref) if the record was successfully created, [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function create_parameter(
    iteration_id::AbstractString, key::AbstractString, value::Real
)::@NamedTuple{id::Optional{String}, status::DataType}
    return create_parameter(iteration_id, key, string(value))
end

"""
    update_parameter(id::AbstractString, key::Optional{AbstractString}, value::Optional{AbstractString})::Type{<:UpsertResult}

Update a [`Parameter`](@ref) record.

# Arguments
- `id::AbstractString`: The id of the parameter to update.
- `key::Optional{AbstractString}`: The new key for the parameter.
- `value::Optional{AbstractString}`: The new value for the parameter.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_parameter(
    id::AbstractString, key::Optional{AbstractString}, value::Optional{AbstractString}
)::Type{<:UpsertResult}
    parameter = get_parameter(id)
    if isnothing(parameter)
        return Unprocessable
    end

    # Ended iterations are immutable.
    iteration = get_iteration(parameter.iteration_id)
    if !(isnothing(iteration)) && !(isnothing(iteration.end_date))
        return Unprocessable
    end

    should_be_updated = compare_object_fields(parameter; key=key, value=value)
    if !should_be_updated
        return Updated
    end

    return update(Parameter, id; key=key, value=value)
end

"""
    update_parameter(id::AbstractString, key::Optional{AbstractString}, value::Real)::Type{<:UpsertResult}

Update a [`Parameter`](@ref) record.

# Arguments
- `id::AbstractString`: The id of the parameter to update.
- `key::Optional{AbstractString}`: The new key for the parameter.
- `value::Real`: The new value for the parameter.

# Returns
An [`UpsertResult`](@ref). [`Updated`](@ref) if the record was successfully updated (or no changes were made), [`Duplicate`](@ref) if the record already exists, [`Unprocessable`](@ref) if the record violates a constraint, and [`Error`](@ref) if an error occurred while creating the record.
"""
function update_parameter(
    id::AbstractString, key::Optional{AbstractString}, value::Real
)::Type{<:UpsertResult}
    return update_parameter(id, key, (string(value)))
end

"""
    delete_parameter(id::AbstractString)::Bool

Delete a [`Parameter`](@ref) record.

# Arguments
- `id::AbstractString`: The id of the parameter to delete.

# Returns
`true` if the record was successfully deleted, `false` otherwise.
"""
function delete_parameter(id::AbstractString)::Bool
    parameter = get_parameter(id)
    if isnothing(parameter)
        return false
    end
    iteration = get_iteration(parameter.iteration_id)
    if !(isnothing(iteration)) && !(isnothing(iteration.end_date))
        # Ended iterations are immutable; refuse single-row deletes. The
        # cascade path used by `delete_iteration` calls the bulk
        # `delete_parameters(iteration)` helper instead.
        return false
    end
    return delete(Parameter, id)
end

"""
    delete_parameters(iteration::Iteration)::Bool

Delete all [`Parameter`](@ref) records associated with a given [`Iteration`](@ref).

# Arguments
- `iteration::Iteration`: The iteration whose parameters are to be deleted.

# Returns
`true` if the records were successfully deleted, `false` otherwise.
"""
delete_parameters(iteration::Iteration)::Bool = delete(Parameter, iteration)

"""
    get_project_id(parameter::Parameter)::Optional{String}

Return the [`Project`](@ref) id that owns the given [`Parameter`](@ref) by walking up to its
parent [`Iteration`](@ref) and [`Experiment`](@ref).

# Arguments
- `parameter::Parameter`: The parameter to inspect.

# Returns
The owning project id, or `nothing` if any ancestor is missing.
"""
function get_project_id(parameter::Parameter)::Optional{String}
    iteration = get_iteration(parameter.iteration_id)
    return isnothing(iteration) ? nothing : (get_project_id(iteration))
end
