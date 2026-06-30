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
DuckDB returns SQL `NULL` as `missing`, matching the previous SQLite behaviour.
"""
row_to_dict(row)::Dict{Symbol,Any} = Dict{Symbol,Any}(pairs(row))

"""
    fetch(query::AbstractString, parameters::NamedTuple)::Optional{Dict{Symbol,Any}}

Execute `query` with `parameters` and return the first row as a dictionary, or `nothing` if
no row matches.
"""
function fetch(query::AbstractString, parameters::NamedTuple)::Optional{Dict{Symbol,Any}}
    result = DBInterface.execute(get_database(), duckdbify(query), parameters)
    state = iterate(Tables.namedtupleiterator(result))
    state === nothing && return nothing
    return row_to_dict(state[1])
end

"""
    fetch_all(query::AbstractString; parameters::NamedTuple=(;))::Array{Dict{Symbol,Any},1}

Execute `query` with `parameters` and return all rows as an array of dictionaries.
"""
function fetch_all(
    query::AbstractString; parameters::NamedTuple=(;)
)::Array{Dict{Symbol,Any},1}
    results = DBInterface.execute(get_database(), duckdbify(query), parameters)
    return [row_to_dict(record) for record in Tables.namedtupleiterator(results)]
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
        result = DBInterface.execute(get_database(), duckdbify(query), parameters)
        record_id = first(Tables.namedtupleiterator(result)).id
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
- `object::Optional{<:UpsertType}`: The record to update (provides the `:id` bind value).
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
        DBInterface.execute(
            get_database(),
            duckdbify(replace(query, "{fields}" => fields)),
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
        DBInterface.execute(get_database(), duckdbify(query), (id=id,))
        return true
    catch _
        return false
    end
end
