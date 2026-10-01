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

If you want to exercise the REST API or the dashboard while developing, copy the sample environment file:

```bash
cp .env.sample .env
```

Every value in the sample is the default. Change the ones you need and delete or comment out the rest: the parser reads an empty value literally, not as the default. Then start the server with `DearDiary.run()`. The REST API listens on port 9000 and the dashboard on port 9001. See [Configuration](https://juliaai.github.io/DearDiary.jl/dev/server/configuration/) for every variable.

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
- **`repositories/sql/`** is the DuckDB implementation behind them: the `SQL_*` query constants and the forward-only migration system (see [Schema migrations](#schema-migrations)).

A few modules sit alongside those layers:

- **`artifacts/`** is pluggable artifact storage. `store.jl` dispatches to the `inline`, `filesystem`, or `s3` backend chosen by `DEARDIARY_ARTIFACT_BACKEND`, and `migrate.jl` moves bytes between backends on a live database.
- **`reproducibility/`** captures and replays environments. `snapshot.jl` records the `Manifest.toml`, Julia version, and git SHA per iteration; `restore.jl` rebuilds that environment.
- **`client/`** is the native Julia client (`connect`, `with_iteration`, and friends) that talks to the REST API, mirroring the route surface for remote logging.
- **`ui/`** is the web dashboard, served as plain server-rendered pages by the HTTP server from [Bonito](https://github.com/SimonDanisch/Bonito.jl): `types.jl` declares the page and context structs, `app.jl` routes a request to a page and wraps it in the document shell, `auth.jl` handles the session cookie and sign-in, `server.jl` boots the server, `pages/` holds one renderer per entity plus the user-management pages and the editing forms in `edit.jl`, and `components.jl`, `charts.jl`, `queries.jl`, and `format.jl` hold the shared building blocks. The stylesheet, client script, and fonts live in `assets/ui/`. `DEARDIARY_ENABLE_UI` toggles it.

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

Every change to the DuckDB schema goes through the forward-only migration system rooted at `src/repositories/sql/migrations.jl`. There is no rollback path. Once a migration is released, treat it as immutable.

To add a new migration:

1. Create `src/repositories/sql/migrations/NNN_short_name.jl` where `NNN` is the next free three-digit version number.
2. In that file, define a `const MIGRATION_NNN_SHORT_NAME = Migration(NNN, "short_name", [...])` whose `statements` list the SQL to apply in order. Re-use the existing `SQL_*` constants when the change is idempotent (e.g. an `IF NOT EXISTS` rebuild) and write inline `ALTER TABLE` strings for additive column changes. DuckDB refuses to alter or rename a column that an index or a foreign key depends on, and a renamed table keeps its foreign-key bookkeeping under the old name. To change such a table, copy it aside, drop it, create it again, and refill it inside one transaction, as `002_model_name_rename.jl` does.
3. Append the new constant to the `MIGRATIONS` vector at the bottom of `src/repositories/sql/migrations.jl`, and add the file to the ordered `include`s there.

With `002` as the highest version on disk, the next migration would look like this:

```julia
# 003_add_metric_unit.jl
const MIGRATION_003_ADD_METRIC_UNIT = Migration(
    3,
    "add_metric_unit",
    ["ALTER TABLE metric ADD COLUMN unit TEXT NOT NULL DEFAULT ''"],
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
