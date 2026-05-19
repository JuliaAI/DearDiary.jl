```@meta
CurrentModule = DearDiary
```

```@raw html
<script async defer src="https://buttons.github.io/buttons.js"></script>
```

# DearDiary.jl
*A lightweight but **powerful** machine learning experiment tracking tool for Julia.*

```@raw html
<a class="github-button"
  href="https://github.com/JuliaAI/DearDiary.jl"
  data-icon="octicon-star"
  data-size="large"
  data-show-count="true"
  aria-label="Star JuliaAI/DearDiary.jl on GitHub">
  Star</a>
```

## Features
- Complete ML experiment tracking — projects, experiments, iterations, parameters,
  metrics, tagged resources.
- Built-in REST API server for remote logging and querying.
- Native Julia client (`DearDiary.connect`, `with_iteration`, …) for logging from training
  scripts running on another machine.
- Model registry with run-to-checkpoint lineage and a
  `NO_STAGE → STAGING → PRODUCTION → ARCHIVED` lifecycle; promoting a version to
  `PRODUCTION` auto-archives the prior incumbent.
- Pluggable artifact storage: bytes can live inline in SQLite, on a local filesystem,
  or in any S3-compatible object store (AWS S3, MinIO, Cloudflare R2).
- Portable SQLite metadata store — one file, no separate service to run.
- **Built in Julia**

Start with the [quickstart](@ref Tutorial), then dive into the dedicated guides for the
[model registry](@ref "Model registry"),
[filesystem artifact storage](@ref "Filesystem artifact storage"),
and [S3 artifact storage](@ref "S3 artifact storage").

## Installation
You can install DearDiary.jl via the Julia package manager:
```julia
using Pkg
Pkg.add("DearDiary")
```

or from the REPL, type `]add DearDiary`.

## Motivation
Experiment tracking is a crucial aspect of machine learning and data science projects.
It helps you keep track of your experiments, models, hyperparameters, and results.
However, many existing experiment tracking tools are either too complex or not
well-integrated with Julia. This package aims to fill that gap by providing a simple yet
powerful solution specifically designed for Julia users.

## Contributing
Contributions are welcome! If you find a bug or have a feature request, please open an
issue on the [GitHub repository](https://github.com/JuliaAI/DearDiary.jl). Pull requests
are also encouraged. Please make sure to follow the existing
[code style](https://github.com/JuliaDiff/BlueStyle) and include tests for any new
features.
