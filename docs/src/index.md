```@meta
CurrentModule = DearDiary
```

```@raw html
<script async defer src="https://buttons.github.io/buttons.js"></script>
```

# DearDiary.jl
*An ML experiment tracker made in Julia.*

```@raw html
<a class="github-button"
  href="https://github.com/JuliaAI/DearDiary.jl"
  data-icon="octicon-star"
  data-size="large"
  data-show-count="true"
  aria-label="Star JuliaAI/DearDiary.jl on GitHub">
  Star</a>
```

```@raw html
<img src="assets/deardiary-logo.svg" width="200" align="right" />
```

New here? Start with [Installation](@ref) and the [Quickstart](@ref).

## Features
- **Tracking surface**: projects, experiments, iterations, parameters, metrics, tagged resources. Iterations form parent/child trees for HPO sweeps and distributed workers, and a status enum records failures with the captured exception text.
- **Server + client**: built-in REST API for remote logging and a native Julia client (`DearDiary.connect`, `with_iteration`, …) that auto-finalises iterations whether the body returns or throws.
- **Bit-exact environment replay**: every iteration records a `Manifest.toml` snapshot, the Julia version, and the git SHA. `DearDiary.restore(iteration_id)` writes the captured environment to a fresh directory for `Pkg.instantiate`.
- **Pluggable storage**: portable DuckDB metadata store. Artifact bytes live inline, on a local filesystem, or in any S3-compatible object store (AWS S3, MinIO, Cloudflare R2). `migrate_artifacts!` moves rows between backends on a live database.

## Motivation
Reproducible ML depends on knowing what code, data, and environment produced each result. Existing trackers either route every interaction through a Python client (MLflow, Weights & Biases, Aim) or capture environments as `pip freeze` strings that re-resolve their transitive dependencies at install time. DearDiary is Julia-native and persists the exact `Manifest.toml` per run, so you can reconstruct an iteration months later by running `DearDiary.restore(iteration_id)`. You use the same tracking API whether you run a single-file DuckDB database on a laptop or a multi-worker S3-backed deployment.

## Contributing
Open an issue or pull request on the [GitHub repository](https://github.com/JuliaAI/DearDiary.jl). Follow the existing [code style](https://github.com/JuliaDiff/BlueStyle) and include tests for new features.
