# Migrations

The database schema evolves through a forward-only migration system. Every release that
changes the schema ships a new numbered [`Migration`](@ref DearDiary.Migration), and
[`initialize_database`](@ref) calls [`apply_migrations`](@ref DearDiary.apply_migrations)
on startup to bring the connected `.db` file up to the current version.

Authoring a new migration is a contributor workflow; see the *Schema migrations* section in
[CONTRIBUTING.md](https://github.com/JuliaAI/DearDiary.jl/blob/main/CONTRIBUTING.md) for the
file-layout conventions and a worked example.

```@docs
DearDiary.Migration
DearDiary.apply_migrations
DearDiary.applied_versions
```
