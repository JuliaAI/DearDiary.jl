# DearDiary.jl
*A lightweight but **powerful** machine learning experiment tracking tool for Julia.*

[![CI](https://github.com/JuliaAI/DearDiary.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaAI/DearDiary.jl/actions/workflows/CI.yml)
[![codecov](https://codecov.io/github/JuliaAI/DearDiary.jl/graph/badge.svg?token=Z01WPRJDNR)](https://codecov.io/github/JuliaAI/DearDiary.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

## Features
<img src="assets/logo.svg" width="200" align="right" />

- A complete experiment tracking solution for Julia.
- Built-in REST API server for remote logging and querying.
- Native Julia client (`DearDiary.connect`, `with_iteration`, …) for logging from training
  scripts running on another machine.
- Portable and easy-to-use SQLite backend.
- **Built in Julia**

Learn to use it with the [Tutorial](https://juliaai.github.io/DearDiary.jl/dev/tutorial/).

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
