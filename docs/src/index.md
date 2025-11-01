```@meta
CurrentModule = TrackingAPI
```

```@raw html
<script async defer src="https://buttons.github.io/buttons.js"></script>
```

# TrackingAPI
*A lightweight but **powerful** experiment tracking tool for Julia.*

```@raw html
<a class="github-button"
  href="https://github.com/pebeto/TrackingAPI.jl"
  data-icon="octicon-star"
  data-size="large"
  data-show-count="true"
  aria-label="Star pebeto/TrackingAPI.jl on GitHub">
  Star</a>
```

## Features
- A complete experiment tracking solution for Julia.
- Built-in REST API server for remote logging and querying.
- Portable and easy-to-use SQLite backend.
- **Built in Julia**

Learn to use it with the [Tutorial](@ref).

## Installation
You can install TrackingAPI.jl via the Julia package manager:
```julia
using Pkg
Pkg.add("TrackingAPI")
```

or from the REPL, type `]add TrackingAPI`.

## Motivation
Experiment tracking is a crucial aspect of machine learning and data science projects.
It helps you keep track of your experiments, models, hyperparameters, and results.
However, many existing experiment tracking tools are either too complex or not
well-integrated with Julia. This package aims to fill that gap by providing a simple yet
powerful solution specifically designed for Julia users.

## Contributing
Contributions are welcome! If you find a bug or have a feature request, please open an
issue on the [GitHub repository](https://github.com/pebeto/TrackingAPI.jl). Pull requests
are also encouraged. Please make sure to follow the existing
[code style](https://github.com/JuliaDiff/BlueStyle) and include tests for any new
features.
