# Reproducibility

Every [`Iteration`](@ref) can carry a bit-exact snapshot of the Julia environment that
produced it — `julia_version`, the HEAD commit SHA of the working tree, the verbatim
`Project.toml` and `Manifest.toml` that were active at run start, and the entrypoint
script. Months later [`restore`](@ref) materialises that snapshot back to disk, so the
exact dependency tree can be `Pkg.instantiate`-d in a fresh depot. Other ML trackers
capture environments as a `pip freeze` string; Julia's `Manifest.toml` is byte-exact, so
the captured tree round-trips with no resolution drift.

```@setup repro
using DearDiary
DearDiary.initialize_database(; file_name=joinpath(mktempdir(), "deardiary.db"))
```

## Capture happens automatically on the driver iteration

[`DearDiary.with_iteration`](@ref) calls [`snapshot_environment!`](@ref) right after
creating the iteration, but only when the new run has no parent. Driver runs capture; child
runs (HPO trials, distributed workers) inherit. Override via the `snapshot` keyword if
you need different behaviour.

```@repl repro
user = DearDiary.get_user("default");
project_id, _ = create_project(user.id, "Repro Project");
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "Training");

iteration_id = DearDiary.with_iteration(experiment_id) do iter
    create_parameter(iter.id, "lr", 1e-3)
    iter.id
end;
```

```@repl repro
iteration = get_iteration(iteration_id);
iteration.julia_version
```

```@repl repro
iteration.git_sha |> length
```

```@repl repro
iteration.entrypoint, iteration.git_dirty
```

## Capture an iteration manually

When you need to attach a snapshot outside the `with_iteration` flow — say, in a long-lived
service that opens iterations imperatively — call [`snapshot_environment!`](@ref) directly:

```@repl repro
manual_id, _ = create_iteration(experiment_id);
DearDiary.snapshot_environment!(manual_id; entrypoint="train.jl");
get_iteration(manual_id).entrypoint
```

[`DearDiary.capture_environment`](@ref) returns the snapshot without persisting it, which
is useful for inspection or for shipping the capture across a process boundary:

```@repl repro
snapshot = DearDiary.capture_environment();
snapshot.julia_version
```

## Replay an environment

[`restore`](@ref) writes the captured `Project.toml` and `Manifest.toml` into a fresh
directory under `depot`. It does **not** activate the project or run `Pkg.instantiate` —
that's left to the caller so the function is side-effect-free outside the temp tree.

```@repl repro
depot = mktempdir();
result = DearDiary.restore(iteration_id; depot=depot)
```

```@repl repro
isfile(joinpath(result.project_path, "Project.toml")), isfile(joinpath(result.project_path, "Manifest.toml"))
```

The on-disk files are byte-identical to what was captured, so loading them with `using
Pkg; Pkg.activate(result.project_path); Pkg.instantiate()` reconstructs the exact
dependency tree the iteration ran against:

```julia
using Pkg
Pkg.activate(result.project_path)
Pkg.instantiate()
# ...then optionally check out the captured commit and run the entrypoint:
# `git checkout $(result.git_sha)` and `julia --project=$(result.project_path) $(result.entrypoint)`
```

## What is and isn't captured

| Captured | Not captured |
|---|---|
| Julia version (`string(VERSION)`) | OS / kernel / glibc |
| HEAD commit SHA + dirty bit | The actual code if `git_dirty == true` and changes are uncommitted |
| Active `Project.toml` (verbatim) | Per-package C library versions outside the JLL system |
| Active `Manifest.toml` (verbatim) | Datasets used by the run (separate concern) |
| Entrypoint script path | Runtime config files outside the project |

If `git_dirty` is `true`, the captured Manifest alone is no longer sufficient for true
reproducibility — there are uncommitted source changes that must be reapplied manually.
Always run reproducible jobs from a clean working tree; the snapshot lets you verify after
the fact whether a job's tree was clean.

```@setup repro
DearDiary.close_database()
```
