"""
    MIGRATION_005_ITERATION_ENVIRONMENT_SNAPSHOT

Adds per-iteration environment-snapshot columns. The intent is bit-exact reproducibility:
given an iteration id, a future operator can reconstruct the Julia toolchain version, the
git commit the code was running from, and the exact dependency tree (`Project.toml` and
`Manifest.toml`) that was loaded.

Columns added:

- `julia_version TEXT DEFAULT ''` — `string(VERSION)` at iteration start.
- `git_sha TEXT DEFAULT ''` — HEAD commit SHA captured via `LibGit2.head_oid`. Empty when
  the iteration ran outside a git working tree.
- `git_dirty INTEGER NOT NULL DEFAULT 0` — `1` when `LibGit2.isdirty(repo)` reported
  uncommitted changes at capture time, `0` otherwise.
- `entrypoint TEXT DEFAULT ''` — `PROGRAM_FILE` at capture time (the script path), or an
  empty string for REPL sessions.
- `project_toml TEXT DEFAULT ''` — the verbatim contents of the active `Project.toml`.
- `manifest_toml TEXT DEFAULT ''` — the verbatim contents of the active `Manifest.toml`.

All defaults are inert sentinels so legacy rows continue to read back as "no snapshot
recorded" and existing code paths are unaffected.
"""
const MIGRATION_005_ITERATION_ENVIRONMENT_SNAPSHOT = Migration(
    5,
    "iteration_environment_snapshot",
    [
        "ALTER TABLE iteration ADD COLUMN julia_version TEXT DEFAULT ''",
        "ALTER TABLE iteration ADD COLUMN git_sha TEXT DEFAULT ''",
        "ALTER TABLE iteration ADD COLUMN git_dirty INTEGER NOT NULL DEFAULT 0",
        "ALTER TABLE iteration ADD COLUMN entrypoint TEXT DEFAULT ''",
        "ALTER TABLE iteration ADD COLUMN project_toml TEXT DEFAULT ''",
        "ALTER TABLE iteration ADD COLUMN manifest_toml TEXT DEFAULT ''",
    ],
)
