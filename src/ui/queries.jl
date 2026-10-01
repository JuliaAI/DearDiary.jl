"""
    _ordinals(iterations)::Dict{String,Int}

Per-experiment ordinals ("Iteration 1, 2, 3…") keyed by iteration id. UUID ids carry no
order, so the ordinal follows `created_date`, which is also how `get_iterations` sorts.
"""
function _ordinals(iterations::AbstractVector{Iteration})::Dict{String,Int}
    sorted = sort(iterations; by=it -> it.created_date)
    return Dict{String,Int}(it.id => i for (i, it) in enumerate(sorted))
end

function _iteration_ordinal(iteration::Iteration)::Int
    siblings = get_iterations(iteration.experiment_id)
    idx = findfirst(sibling -> sibling.id == iteration.id, siblings)
    return isnothing(idx) ? 0 : idx
end

function _status_counts(iterations::AbstractVector{Iteration})::Dict{Int64,Int}
    counts = Dict{Int64,Int}()
    for it in iterations
        counts[it.status_id] = get(counts, it.status_id, 0) + 1
    end
    return counts
end

_count(counts::Dict{Int64,Int}, status::IterationStatus)::Int =
    get(counts, Integer(status), 0)

function _last_activity(iterations::AbstractVector{Iteration})::Optional{DateTime}
    latest = nothing
    for it in iterations
        for stamp in (it.created_date, it.end_date)
            isnothing(stamp) && continue
            if isnothing(latest) || stamp > latest
                latest = stamp
            end
        end
    end
    return latest
end

_duration(iteration::Iteration)::Optional{Millisecond} =
    isnothing(iteration.end_date) ? nothing : iteration.end_date - iteration.created_date

"""
    _tree_order(iterations)::Vector{Tuple{Iteration,Int}}

Flatten an experiment's iterations so every child follows its parent, paired with its
nesting depth. Orphans whose parent lives in another experiment (or was deleted) are
treated as roots so they never vanish from the table.
"""
function _tree_order(iterations::AbstractVector{Iteration})::Vector{Tuple{Iteration,Int}}
    ids = Set(it.id for it in iterations)
    children = Dict{String,Vector{Iteration}}()
    roots = Iteration[]
    for it in sort(iterations; by=i -> i.created_date)
        parent = it.parent_iteration_id
        if isnothing(parent) || !(parent in ids)
            push!(roots, it)
        else
            push!(get!(children, parent, Iteration[]), it)
        end
    end
    out = Tuple{Iteration,Int}[]
    function visit(it, depth)
        push!(out, (it, depth))
        for child in get(children, it.id, Iteration[])
            visit(child, depth + 1)
        end
    end
    for root in roots
        visit(root, 0)
    end
    return out
end

# One metric key on an iteration: the latest value and the step it was logged at, the
# first value, the finite extrema, the number of points, and every value for the sparkline.
struct MetricSummary
    key::String
    last::Float64
    last_step::Int64
    first::Float64
    min::Float64
    max::Float64
    count::Int
    values::Vector{Float64}
end

"""
    _series(metrics)::Dict{String,Vector{Tuple{Int64,Float64}}}

Group metric rows by key into `(step, value)` series sorted by step.
"""
function _series(metrics::AbstractVector{Metric})::Dict{String,Vector{Tuple{Int64,Float64}}}
    grouped = Dict{String,Vector{Tuple{Int64,Float64}}}()
    for m in metrics
        push!(get!(grouped, m.key, Tuple{Int64,Float64}[]), (m.step, m.value))
    end
    for points in values(grouped)
        sort!(points; by=first)
    end
    return grouped
end

function _metric_summaries(metrics::AbstractVector{Metric})::Vector{MetricSummary}
    grouped = _series(metrics)
    summaries = MetricSummary[]
    for key in sort(collect(keys(grouped)))
        points = grouped[key]
        vals = [p[2] for p in points]
        finite = filter(isfinite, vals)
        lo, hi = isempty(finite) ? (NaN, NaN) : extrema(finite)
        push!(
            summaries,
            MetricSummary(
                key,
                last(points)[2],
                last(points)[1],
                first(points)[2],
                lo,
                hi,
                length(points),
                vals,
            ),
        )
    end
    return summaries
end

struct IterationRow
    iteration::Iteration
    ordinal::Int
    depth::Int
    parent_ordinal::Optional{Int}
    parameters::Dict{String,String}
    metrics::Dict{String,Vector{Tuple{Int64,Float64}}}
    tags::Vector{Tag}
end

"""
    _iteration_rows(iterations)::Vector{IterationRow}

Everything the experiment page needs per iteration, in tree order: ordinal, lineage,
parameters, metric series, and tags.
"""
function _iteration_rows(iterations::AbstractVector{Iteration})::Vector{IterationRow}
    ordinals = _ordinals(iterations)
    rows = IterationRow[]
    for (it, depth) in _tree_order(iterations)
        parent_ordinal = if isnothing(it.parent_iteration_id)
            nothing
        else
            get(ordinals, it.parent_iteration_id, nothing)
        end
        params = Dict{String,String}(p.key => p.value for p in get_parameters(it.id))
        push!(
            rows,
            IterationRow(
                it,
                ordinals[it.id],
                depth,
                parent_ordinal,
                params,
                _series(get_metrics(it.id)),
                get_tags(Iteration, it.id),
            ),
        )
    end
    return rows
end

_parameter_keys(rows::AbstractVector{IterationRow})::Vector{String} =
    sort(unique(k for row in rows for k in keys(row.parameters)))

_metric_keys(rows::AbstractVector{IterationRow})::Vector{String} =
    sort(unique(k for row in rows for k in keys(row.metrics)))

function _final_value(row::IterationRow, key::AbstractString)::Optional{Float64}
    points = get(row.metrics, key, nothing)
    return isnothing(points) || isempty(points) ? nothing : last(points)[2]
end

struct ExperimentSummary
    experiment::Experiment
    iterations::Vector{Iteration}
    counts::Dict{Int64,Int}
    last_activity::Optional{DateTime}
    tags::Vector{Tag}
end

function _experiment_summary(experiment::Experiment)::ExperimentSummary
    iterations = get_iterations(experiment.id)
    return ExperimentSummary(
        experiment,
        iterations,
        _status_counts(iterations),
        _last_activity(iterations),
        get_tags(Experiment, experiment.id),
    )
end

struct ProjectSummary
    project::Project
    experiments::Vector{ExperimentSummary}
    models::Vector{Model}
    tags::Vector{Tag}
end

function _project_summary(project::Project)::ProjectSummary
    experiments = [_experiment_summary(e) for e in get_experiments(project.id)]
    return ProjectSummary(
        project, experiments, get_models(project.id), get_tags(Project, project.id)
    )
end

_iteration_count(summary::ProjectSummary)::Int =
    sum(length(e.iterations) for e in summary.experiments; init=0)

function _status_counts(summary::ProjectSummary)::Dict{Int64,Int}
    counts = Dict{Int64,Int}()
    for e in summary.experiments
        for (status, n) in e.counts
            counts[status] = get(counts, status, 0) + n
        end
    end
    return counts
end

function _last_activity(summary::ProjectSummary)::Optional{DateTime}
    stamps = [e.last_activity for e in summary.experiments if !isnothing(e.last_activity)]
    return isempty(stamps) ? nothing : maximum(stamps)
end

"""
    _versions_for_iteration(project_id, iteration_id)::Vector{Tuple{Model,ModelVersion}}

Model versions registered from a given iteration, scanned across the project's registry.
"""
function _versions_for_iteration(
    project_id::AbstractString, iteration_id::AbstractString
)::Vector{Tuple{Model,ModelVersion}}
    out = Tuple{Model,ModelVersion}[]
    for model in get_models(project_id)
        for version in get_modelversions(model.id)
            version.iteration_id == iteration_id && push!(out, (model, version))
        end
    end
    return out
end

function _production_version(versions::AbstractVector{ModelVersion})::Optional{ModelVersion}
    idx = findfirst(v -> v.stage_id == Integer(PRODUCTION), versions)
    return isnothing(idx) ? nothing : versions[idx]
end
