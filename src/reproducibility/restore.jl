"""
    RestoreResult

Materialised view returned by [`restore`](@ref). Carries the on-disk location of the
reconstructed project plus the surrounding lineage metadata so the caller can drive
`Pkg.instantiate` (or invoke `julia --project=…`) and check the result against the
captured `git_sha` / `git_dirty` / `julia_version`.

Fields
- `project_path::String`: Directory containing the materialised `Project.toml` and
  `Manifest.toml`. Activate it via `Pkg.activate(project_path)` to use it.
- `julia_version::String`: The Julia version recorded at capture time.
- `git_sha::String`: The HEAD commit SHA at capture time, or empty when no git state was
  captured.
- `git_dirty::Bool`: `true` when the working tree was dirty at capture time. A `true`
  value warns that the captured Manifest may not be reproducible from `git_sha` alone.
- `entrypoint::String`: The script that was the iteration's entrypoint, or empty for REPL
  sessions.
"""
struct RestoreResult
    project_path::String
    julia_version::String
    git_sha::String
    git_dirty::Bool
    entrypoint::String
end

"""
    restore(iteration_id::Integer; depot::AbstractString=mktempdir())::RestoreResult

Materialise the captured Pkg environment of `iteration_id` into a fresh directory under
`depot`. Writes `Project.toml` and `Manifest.toml` from the iteration row; does **not**
itself call `Pkg.instantiate` or activate the project — that's deliberately left to the
caller so this function stays side-effect-free outside of the temp directory.

A typical workflow:

```julia
result = DearDiary.restore(iteration_id)
using Pkg
Pkg.activate(result.project_path)
Pkg.instantiate()
# ...then run `result.entrypoint` if one was captured.
```

# Arguments
- `iteration_id::Integer`: The iteration whose environment to restore.
- `depot::AbstractString`: Directory under which to create the project subdirectory.
  Defaults to a fresh tempdir.

# Returns
A [`RestoreResult`](@ref).

# Throws
- `ArgumentError` when the iteration does not exist.
- `ArgumentError` when the iteration has no captured manifest — i.e.
  [`snapshot_environment!`](@ref) was never invoked on it.
"""
function restore(
    iteration_id::Integer; depot::AbstractString=mktempdir(),
)::RestoreResult
    iteration = iteration_id |> get_iteration
    if iteration |> isnothing
        throw(ArgumentError("Iteration $iteration_id not found"))
    end
    if iteration.manifest_toml |> isempty
        throw(ArgumentError(
            "Iteration $iteration_id has no captured environment — " *
            "call snapshot_environment! before restore.",
        ))
    end

    project_dir = joinpath(depot, "iteration_$(iteration_id)")
    mkpath(project_dir)
    write(joinpath(project_dir, "Project.toml"), iteration.project_toml)
    write(joinpath(project_dir, "Manifest.toml"), iteration.manifest_toml)

    return RestoreResult(
        project_dir,
        iteration.julia_version,
        iteration.git_sha,
        iteration.git_dirty,
        iteration.entrypoint,
    )
end
