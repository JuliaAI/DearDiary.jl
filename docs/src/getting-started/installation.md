# Installation

DearDiary is a registered Julia package.

```julia
using Pkg
Pkg.add("DearDiary")
```

Or from the Pkg REPL (press `]`):

```julia-repl
pkg> add DearDiary
```

DearDiary supports Julia 1.10 and later. It ships its own embedded DuckDB store, so there
is no database server to install.
