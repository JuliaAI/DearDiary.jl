# DearDiary.jl
*An ML experiment tracker made in Julia.*

[![CI](https://github.com/JuliaAI/DearDiary.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaAI/DearDiary.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/github/JuliaAI/DearDiary.jl/graph/badge.svg?token=Z01WPRJDNR)](https://codecov.io/github/JuliaAI/DearDiary.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliaai.github.io/DearDiary.jl/dev/)

## Features
<img src="assets/logo.svg" width="200" align="right" />

- **Tracking surface**: projects, experiments, iterations, parameters, metrics, tagged resources. Iterations form parent/child trees for HPO sweeps and distributed workers, and a status enum records failures with the captured exception text.
- **Server + client**: built-in REST API for remote logging and a native Julia client (`DearDiary.connect`, `with_iteration`, …) that auto-finalises iterations whether the body returns or throws.
- **Bit-exact environment replay**: every iteration records a `Manifest.toml` snapshot, the Julia version, and the git SHA. `DearDiary.restore(iteration_id)` writes the captured environment to a fresh directory for `Pkg.instantiate`.
- **Pluggable storage**: portable SQLite metadata store. Artifact bytes live inline, on a local filesystem, or in any S3-compatible object store (AWS S3, MinIO, Cloudflare R2). `migrate_artifacts!` moves rows between backends on a live database.

The [tutorials](https://juliaai.github.io/DearDiary.jl/dev/tutorial/) cover a quickstart walk-through plus dedicated guides for the [model registry](https://juliaai.github.io/DearDiary.jl/dev/tutorial/model_registry/), [child iterations](https://juliaai.github.io/DearDiary.jl/dev/tutorial/child_iterations/), [filesystem](https://juliaai.github.io/DearDiary.jl/dev/tutorial/filesystem_artifacts/) and [S3](https://juliaai.github.io/DearDiary.jl/dev/tutorial/s3_artifacts/) artifact storage, and [Manifest-based reproducibility](https://juliaai.github.io/DearDiary.jl/dev/tutorial/reproducibility/).

## Installation
```julia
using Pkg
Pkg.add("DearDiary")
```
or from the REPL, type `]add DearDiary`.

## Quickstart
```julia
using DearDiary
DearDiary.initialize_database()

user = DearDiary.get_user("default")
project_id, _ = create_project(user.id, "Iris classification")
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "Decision-tree sweep")

with_iteration(experiment_id) do iter
    create_parameter(iter.id, "max_depth", 7)
    create_metric(iter.id, "accuracy", 0.96)
end
```

`with_iteration` opens an iteration, runs the body, marks it `SUCCEEDED` on a clean return or `FAILED` (carrying the captured exception text) on a throw, and snapshots the active Julia environment so you can replay the run later. The [tutorials](https://juliaai.github.io/DearDiary.jl/dev/tutorial/) cover remote logging through the REST client, the model registry, and the reproducibility workflow.

## Motivation
Reproducible ML depends on knowing what code, data, and environment produced each result. Existing trackers either route every interaction through a Python client (MLflow, Weights & Biases, Aim) or capture environments as `pip freeze` strings that re-resolve their transitive dependencies at install time. DearDiary is Julia-native and persists the exact `Manifest.toml` per run, so you can reconstruct an iteration months later by running `DearDiary.restore(iteration_id)`. You use the same tracking API whether you run a single-file SQLite database on a laptop or a multi-worker S3-backed deployment.

## Contributing
Open an issue or pull request on the [GitHub repository](https://github.com/JuliaAI/DearDiary.jl). Follow the existing [code style](https://github.com/JuliaDiff/BlueStyle) and include tests for new features.
