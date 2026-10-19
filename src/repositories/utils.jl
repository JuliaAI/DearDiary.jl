const _NAMED_PARAM = r":([A-Za-z_][A-Za-z0-9_]*)"
"""
    duckdbify(query::AbstractString)::String

Rewrite `:name` bind-parameter placeholders to DuckDB's `\$name` form. DuckDB's SQL parser
rejects the `:name` syntax that the rest of the repository (and `DBInterface` convention)
writes, so every query is normalized at this single execute choke point rather than editing
each SQL constant. DDL strings contain no `:` tokens, so this is a no-op for them.
"""
duckdbify(query::AbstractString)::String = replace(query, _NAMED_PARAM => s"$\1")

"""
    row_to_dict(row)::Dict{Symbol,Any}

Convert a query row (a `NamedTuple` from `Tables.namedtupleiterator`) to a dictionary.
DuckDB returns SQL `NULL` as `missing`, which `type_from_dict` turns into `nothing` for
nullable fields.
"""
row_to_dict(row)::Dict{Symbol,Any} = Dict{Symbol,Any}(pairs(row))

"""
    execute_query(f::Function, query::AbstractString, parameters::NamedTuple=(;))
    execute_query(f::Function, db::DuckDB.DB, query::AbstractString, parameters::NamedTuple=(;))

Run `query` with `parameters` under the database lock, pass the result to `f`, destroy the
result and the prepared statement, and return what `f` returned. `f` must copy what it
needs out of the result; the row helpers below build dictionaries from the Julia-owned
columns that `Tables.columns` materialises.

The statement and the result are destroyed here instead of by their finalizers, so nothing
but the `DB` object keeps the instance alive when [`close_database`](@ref) runs, whatever
the thread count. The generic `DBInterface.execute(db, sql, parameters)` leaves the
prepared statement to its finalizer, which is why the statement is prepared and closed
explicitly. Without an explicit `db`, the open database from [`get_database`](@ref) is
used, read under the lock so a concurrent close cannot hand over an instance that is going
away.
"""
function execute_query(
    f::Function, db::DuckDB.DB, query::AbstractString, parameters::NamedTuple=(;)
)
    return with_database_lock() do
        stmt = DBInterface.prepare(db, duckdbify(query))
        try
            result = DBInterface.execute(stmt, parameters)
            try
                f(result)
            finally
                DBInterface.close!(result)
            end
        finally
            DBInterface.close!(stmt)
        end
    end
end
function execute_query(f::Function, query::AbstractString, parameters::NamedTuple=(;))
    return with_database_lock() do
        execute_query(f, get_database(), query, parameters)
    end
end

"""
    execute_statement(query::AbstractString, parameters::NamedTuple=(;))::Nothing
    execute_statement(db::DuckDB.DB, query::AbstractString, parameters::NamedTuple=(;))::Nothing

Run a statement whose rows are not needed, such as an UPDATE, a DELETE, or DDL, through
[`execute_query`](@ref).
"""
function execute_statement(query::AbstractString, parameters::NamedTuple=(;))::Nothing
    execute_query(_ -> nothing, query, parameters)
    return nothing
end
function execute_statement(
    db::DuckDB.DB, query::AbstractString, parameters::NamedTuple=(;)
)::Nothing
    execute_query(_ -> nothing, db, query, parameters)
    return nothing
end

"""
    fetch(query::AbstractString, parameters::NamedTuple)::Optional{Dict{Symbol,Any}}

Execute `query` with `parameters` and return the first row as a dictionary, or `nothing` if
no row matches.
"""
function fetch(query::AbstractString, parameters::NamedTuple)::Optional{Dict{Symbol,Any}}
    return execute_query(query, parameters) do result
        state = iterate(Tables.namedtupleiterator(result))
        (state === nothing) ? nothing : (row_to_dict(state[1]))
    end
end

"""
    fetch_all(query::AbstractString; parameters::NamedTuple=(;))::Array{Dict{Symbol,Any},1}

Execute `query` with `parameters` and return all rows as an array of dictionaries.
"""
function fetch_all(
    query::AbstractString; parameters::NamedTuple=(;)
)::Array{Dict{Symbol,Any},1}
    return execute_query(query, parameters) do result
        [row_to_dict(record) for record in Tables.namedtupleiterator(result)]
    end
end

"""
    fetch_count(query::AbstractString; parameters::NamedTuple=(;))::Int64

Run a `SELECT COUNT(*) AS count FROM ...` query and return the count, or `0` if the query
returns no rows.
"""
function fetch_count(query::AbstractString; parameters::NamedTuple=(;))::Int64
    row = fetch(query, parameters)
    return (isnothing(row)) ? 0 : (Int64(row[:count]))
end

"""
    fetch_page(select_query, count_query; parameters, page::Pagination)::@NamedTuple{rows, total}

Execute `select_query` (with `LIMIT :limit OFFSET :offset` appended) and `count_query` in one
call. Returns raw dictionaries; concrete entity overloads typically wrap these into a
[`PaginatedResponse`](@ref).

# Arguments
- `select_query::AbstractString`: SELECT query without `LIMIT`/`OFFSET`; the helper appends them.
- `count_query::AbstractString`: COUNT query filtered by the same parameters.
- `parameters::NamedTuple`: Filter parameters shared by both queries.
- `page::Pagination`: Page bounds.

# Returns
A NamedTuple `(rows::Array{Dict{Symbol,Any},1}, total::Int64)`.
"""
function fetch_page(
    select_query::AbstractString,
    count_query::AbstractString;
    parameters::NamedTuple=(;),
    page::Pagination,
)::@NamedTuple{rows::Array{Dict{Symbol,Any},1}, total::Int64}
    paged_query = select_query * " LIMIT :limit OFFSET :offset"
    paged_params = merge(parameters, (limit=page.limit, offset=page.offset))
    rows = fetch_all(paged_query; parameters=paged_params)
    total = fetch_count(count_query; parameters=parameters)
    return (rows=rows, total=total)
end

"""
    insert(query::AbstractString, parameters::NamedTuple)::NamedTuple{id::Optional{String},status::DataType}

Execute an INSERT and return the new row id with a status code.

# Arguments
- `query::AbstractString`: The INSERT query (must use `RETURNING id`).
- `parameters::NamedTuple`: Bind parameters.

# Returns
A named tuple `(id, status)` where `status` is one of [`Created`](@ref),
[`Duplicate`](@ref), [`Unprocessable`](@ref), or [`Error`](@ref). On failure `id` is
`nothing`.
"""
function insert(
    query::AbstractString, parameters::NamedTuple
)::@NamedTuple{id::Optional{String}, status::DataType}
    try
        record_id = execute_query(query, parameters) do result
            first(Tables.namedtupleiterator(result)).id
        end
        return (id=record_id, status=Created)
    catch exception
        msg = sprint(showerror, exception)
        if occursin("violates unique constraint", msg) ||
            occursin("violates primary key constraint", msg)
            return (id=nothing, status=Duplicate)
        elseif occursin("CHECK constraint failed", msg)
            return (id=nothing, status=Unprocessable)
        elseif occursin("foreign key constraint", lowercase(msg))
            return (id=nothing, status=Unprocessable)
        elseif occursin("NOT NULL constraint failed", msg)
            return (id=nothing, status=Unprocessable)
        else
            return (id=nothing, status=Error)
        end
    end
end

"""
    update(query::AbstractString, object::Optional{<:ResultType}; parameters...)::Type{<:UpsertResult}

Execute an UPDATE for `object`, setting only the non-`nothing` keyword fields.

# Arguments
- `query::AbstractString`: UPDATE query with a `{fields}` placeholder and `:id` bind.
- `object::Optional{<:ResultType}`: The record to update (provides the `:id` bind value).
- `parameters`: Fields to update; `nothing` values are skipped.

# Returns
[`Updated`](@ref) on success, [`Unprocessable`](@ref) on constraint violation, or
[`Error`](@ref) on any other failure.
"""
function update(
    query::AbstractString, object::Optional{<:ResultType}; parameters...
)::Type{<:UpsertResult}
    try
        parameters = NamedTuple(parameters)
        fields = join(
            ["$key=:$key" for key in (keys(parameters)) if !isnothing(parameters[key])],
            ", ",
        )
        execute_statement(
            replace(query, "{fields}" => fields),
            merge(parameters, (id=getfield(object, :id),)),
        )
        return Updated
    catch exception
        msg = sprint(showerror, exception)
        if occursin("CHECK constraint failed", msg) ||
            occursin("foreign key constraint", lowercase(msg))
            return Unprocessable
        else
            return Error
        end
    end
end

"""
    delete(query::AbstractString, id::AbstractString)::Bool

Execute a DELETE for the row identified by `id`. Returns `true` on success, `false` on error.
"""
function delete(query::AbstractString, id::AbstractString)::Bool
    try
        execute_statement(query, (id=id,))
        return true
    catch _
        return false
    end
end
