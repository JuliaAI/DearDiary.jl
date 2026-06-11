# Contributing to DearDiary

We welcome bug fixes, new features, documentation, tests, and ideas. Below is the path from a fresh clone to an open pull request, followed by the conventions we follow.

If you get stuck, **open an issue** on the [GitHub repository](https://github.com/JuliaAI/DearDiary.jl). A question is a fine reason to open one.

## Getting started

You need Julia ≥ 1.10 (CI runs on the current `lts` and latest `1` releases).

```bash
git clone https://github.com/JuliaAI/DearDiary.jl
cd DearDiary.jl
```

Instantiate the project and run the test suite from the package REPL:

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
Pkg.test()
```

or in one line from your shell:

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

The tests are self-contained: they create their own temporary database and environment file and clean up afterwards, so you don't need to set up a database to run them.

When everything passes, you're ready to make changes:

> 1. Create a branch off `dev`
> 2. Make your changes, with tests and documentation
> 3. Open a pull request **against the `dev` branch** (CI runs there)

## Finding something to work on

- Browse the [open issues](https://github.com/JuliaAI/DearDiary.jl/issues) and look for the *good first issue* label.
- For a larger change, open an issue first so we can agree on the approach before you write the code. It usually gets the PR merged faster.

## Running the server locally (optional)

If you want to exercise the REST API while developing, copy the sample environment file and fill in the values:

```bash
cp .env.sample .env
```

Then start the server with `DearDiary.run()`. See the [tutorials](https://juliaai.github.io/DearDiary.jl/dev/tutorial/) for the full workflow.

To build the documentation locally:

```bash
julia --project=docs -e 'using Pkg; Pkg.instantiate()' && julia --project=docs docs/make.jl
```

## Project architecture

DearDiary uses a functional style (immutability and multiple dispatch) and is organised into modules under `src/`, each owning one job. A server request flows down through the layers and back up:

- **`types/`** holds the domain model: structs for users, projects, experiments, iterations, parameters, metrics, resources, tags, and models, plus the enums, errors, and `APIConfig`. Everything else builds on these.
- **`routes/`** defines the REST API: thin HTTP handlers that parse a request and delegate to a service. `routes/auth.jl` and the `AuthMiddleware` in `src/DearDiary.jl` handle JWT auth.
- **`services/`** holds the business logic. It validates input, hashes passwords, enforces rules, and orchestrates repositories. Both the routes and the client call into here.
- **`repositories/`** is backend-agnostic data access. Functions like `fetch`, `insert`, and `update` dispatch on the domain type, e.g. `fetch(::Type{<:User}, id)`.
- **`repositories/sql/`** is the SQLite implementation behind them: the `SQL_*` query constants and the forward-only migration system (see [Schema migrations](#schema-migrations)).

A few modules sit alongside those layers:

- **`artifacts/`** is pluggable artifact storage. `store.jl` dispatches to the `sqlite`, `filesystem`, or `s3` backend chosen by `DEARDIARY_ARTIFACT_BACKEND`, and `migrate.jl` moves bytes between backends on a live database.
- **`reproducibility/`** captures and replays environments. `snapshot.jl` records the `Manifest.toml`, Julia version, and git SHA per iteration; `restore.jl` rebuilds that environment.
- **`client/`** is the native Julia client (`connect`, `with_iteration`, and friends) that talks to the REST API, mirroring the route surface for remote logging.
- **`ui/`** is the [Bonito](https://github.com/SimonDanisch/Bonito.jl) web frontend: `app.jl` builds it, `server.jl` serves it, and `DEARDIARY_ENABLE_UI` toggles it.

Keep each change in the module that owns that responsibility, and picture the next person who will read your code.

## Code style

We follow the [BlueStyle](https://github.com/JuliaDiff/BlueStyle) guidelines, applied with [JuliaFormatter.jl](https://github.com/domluna/JuliaFormatter.jl). The repository ships a `.JuliaFormatter.toml`, so run the formatter from the repository root before you open a PR:

```julia
using JuliaFormatter
format(".")
```

> [!NOTE]
> The formatter handles layout. The conventions below are **house preferences** it can't check for you. We won't block a useful PR over them. A maintainer might tidy them on merge or point them out so you can pick up the local style. Don't let them stop you from contributing.

### Multiple dispatch over branching

Dispatch on types instead of branching on them at runtime. It reads as idiomatic Julia and keeps the code open to extension.

```julia
# Preferred
process(data::DataType1) = ...
process(data::DataType2) = ...

# Avoid: runtime type checks
function process(data)
    if isa(data, DataType1)
        ...
    elseif isa(data, DataType2)
        ...
    end
end
```

### Type annotations

Annotate where it documents intent or constrains a public API; don't over-annotate.

- **Struct fields**: annotate with concrete types. It keeps stored data well-defined and helps performance.
- **Function arguments**: annotate with abstract types so functions stay generic and composable.
- **Return types**: annotate only when it clarifies or constrains the contract. Julia specializes on call, so a blanket `::ConcreteType` on every return buys no performance and can hide bugs by inserting an implicit `convert`. Add one where you want to constrain the type.

```julia
struct ExampleType
    field1::Int64
    field2::String
end

function example_function(arg1::Integer, arg2::AbstractString)
    # function body
end
```

### Schema migrations

Every change to the SQLite schema goes through the forward-only migration system rooted at `src/repositories/sql/migrations.jl`. There is no rollback path. Once a migration is released, treat it as immutable.

To add a new migration:

1. Create `src/repositories/sql/migrations/NNN_short_name.jl` where `NNN` is the next free three-digit version number.
2. In that file, define a `const MIGRATION_NNN_SHORT_NAME = Migration(NNN, "short_name", [...])` whose `statements` list the SQL to apply in order. Re-use the existing `SQL_*` constants when the change is idempotent (e.g. an `IF NOT EXISTS` rebuild) and write inline `ALTER TABLE` strings for additive column changes.
3. Append the new constant to the `MIGRATIONS` vector at the bottom of `src/repositories/sql/migrations.jl`, and add the file to the ordered `include`s there.

```julia
# 002_add_metric_step_recorded_at.jl
const MIGRATION_002_ADD_METRIC_STEP_RECORDED_AT = Migration(
    2,
    "add_metric_step_recorded_at",
    [
        "ALTER TABLE metric ADD COLUMN step INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE metric ADD COLUMN recorded_at TEXT NOT NULL DEFAULT ''",
    ],
)
```

When the server starts, `initialize_database()` runs every pending migration in version order and stamps each one into the `schema_migrations` table, so an existing database only ever sees the new statements.

### Documentation

Document anything users will touch with a docstring. Internal helpers don't need one, but name them so they explain themselves.

```julia
"""
    example_function(arg1::Integer, arg2::AbstractString)

Take an integer and a string and return a float.

# Arguments
- `arg1::Integer`: the first argument.
- `arg2::AbstractString`: the second argument.

# Returns
- `Float64`: the result.
"""
function example_function(arg1::Integer, arg2::AbstractString)
    return 0.0
end
```

## AI-assisted contributions

Use AI tools if they help, but review, understand, and test everything yourself before it goes into a PR. You answer for what you submit.

## Being kind

We want DearDiary to be a welcoming place to contribute. Be respectful in issues and pull requests, and assume good faith.
