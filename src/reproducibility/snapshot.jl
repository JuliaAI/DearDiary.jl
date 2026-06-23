"""
    EnvironmentSnapshot

The bundle of metadata captured by [`capture_environment`](@ref) and persisted on an
[`Iteration`](@ref) row by [`snapshot_environment!`](@ref).

Fields
- `julia_version::String`: `string(VERSION)` at capture time.
- `git_sha::String`: HEAD commit SHA from the working tree, or `""` if no git repo is
  reachable from the current directory.
- `git_dirty::Bool`: `true` when uncommitted changes were detected at capture time.
- `entrypoint::String`: `PROGRAM_FILE` (the script path), or `""` for REPL sessions.
- `project_toml::String`: Verbatim contents of the active `Project.toml`. Empty when no
  active project is set (raw REPL with no `--project`).
- `manifest_toml::String`: Verbatim contents of the active `Manifest.toml`. Empty when no
  active project is set or the project has never been resolved.
"""
struct EnvironmentSnapshot
    julia_version::String
    git_sha::String
    git_dirty::Bool
    entrypoint::String
    project_toml::String
    manifest_toml::String
end

"""
    capture_environment(; entrypoint::AbstractString=PROGRAM_FILE)::EnvironmentSnapshot

Capture a snapshot of the calling Julia process's reproducibility-relevant state.

The function never throws: missing git repo, missing active project, and unreadable
toml files all degrade gracefully to empty strings so a partial capture is preferable
to a hard failure mid-iteration.

# Arguments
- `entrypoint::AbstractString`: Override the captured script path. Defaults to
  `PROGRAM_FILE`, which is empty in REPL sessions.

# Returns
An [`EnvironmentSnapshot`](@ref).
"""
function capture_environment(; entrypoint::AbstractString=PROGRAM_FILE)::EnvironmentSnapshot
    julia_version = string(VERSION)
    git_sha, git_dirty = _git_state()
    project_toml, manifest_toml = _pkg_state()
    return EnvironmentSnapshot(
        julia_version, git_sha, git_dirty, string(entrypoint), project_toml, manifest_toml
    )
end

"""
    _git_state()::Tuple{String,Bool}

Probe the working tree for git state. Walks up from `pwd()` looking for a `.git` directory
via `LibGit2.GitRepoExt`. Returns `("", false)` when no repository is reachable, when
LibGit2 fails to open it, or when reading HEAD fails.
"""
function _git_state()::Tuple{String,Bool}
    try
        repo = LibGit2.GitRepoExt(pwd())
        try
            sha = string(LibGit2.head_oid(repo))
            dirty = LibGit2.isdirty(repo)
            return (sha, dirty)
        finally
            LibGit2.close(repo)
        end
    catch
        return ("", false)
    end
end

"""
    _pkg_state()::Tuple{String,String}

Return the verbatim contents of the active `Project.toml` and `Manifest.toml`. Returns
empty strings when no active project is set or the manifest has not yet been resolved,
so capture stays non-fatal in environments where Pkg state is incomplete.
"""
function _pkg_state()::Tuple{String,String}
    project_path = Base.active_project()
    if (isnothing(project_path)) || !(isfile(project_path))
        return ("", "")
    end
    project_dir = dirname(project_path)
    project_toml = (isfile(project_path)) ? read(project_path, String) : ""
    manifest_path = joinpath(project_dir, "Manifest.toml")
    manifest_toml = (isfile(manifest_path)) ? read(manifest_path, String) : ""
    return (project_toml, manifest_toml)
end
