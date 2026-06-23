# Filesystem artifact storage

By default, DearDiary stores every [`Resource`](@ref) artifact inline in the database.
That works for kilobyte-sized configs and small pickled models, but a 500 MB checkpoint
will balloon the database file and slow every metadata query. The
[`DearDiary.FilesystemStore`](@ref) backend writes artifact bytes to a directory on local
disk, keeping the database lean and letting you back up the bytes with the rest of your
storage volume.

## Configuration

Set two environment variables in your `.env`:

```text
DEARDIARY_ARTIFACT_BACKEND=filesystem
DEARDIARY_ARTIFACT_FS_ROOT=/var/lib/deardiary/artifacts
```

The root directory is created on the first write. No separate provisioning step is needed.

## Layout on disk

Each artifact is written to `<root>/<aa>/<uuid>`, where `<aa>` is a two-character shard of
the UUID so no single directory grows unbounded. Two uploads of identical bytes produce
distinct files: there is no content-addressed deduplication, so deleting one
[`Resource`](@ref) cannot break a sibling that uploaded the same payload.

```@setup fs
using DearDiary
artifact_root = mktempdir()
DearDiary._DEARDIARY_APICONFIG = DearDiary.APIConfig(
    "127.0.0.1", UInt16(0), joinpath(mktempdir(), "deardiary.db"),
    "tutorial-secret", false, ["*"],
    "filesystem", artifact_root,
    "", "", "us-east-1", "", "",
    false, "127.0.0.1", UInt16(0),
)
DearDiary.initialize_database(; file_name=DearDiary._DEARDIARY_APICONFIG.db_file)
```

## End-to-end example

Create a project, experiment, and iteration, then upload an artifact through the configured store:

```@repl fs
user = DearDiary.get_user("default");
project_id, _ = create_project(user.id, "Filesystem tutorial");
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "FS experiment");
iteration_id, _ = create_iteration(experiment_id);
payload = rand(UInt8, 4096);
resource_id, _ = create_resource(experiment_id, "checkpoint.bin", payload);
```

The resource row records the new backend and the URI that points at the bytes on disk:

```@repl fs
resource = get_resource(resource_id)
```

```@repl fs
resource.backend
```

```@repl fs
resource.uri |> startswith("file://")
```

The on-disk path is reachable directly for inspection or streaming from another process. DearDiary itself reads through [`read_resource_data`](@ref):

```@repl fs
read_resource_data(resource_id) == payload
```

## Migrating from the SQLite backend

If a project was started on the SQLite backend and you later switch
`DEARDIARY_ARTIFACT_BACKEND` to `filesystem`, run [`migrate_artifacts!`](@ref) once to
move the legacy inline bytes to disk:

```julia
using DearDiary
DearDiary.run(; env_file=".env")
DearDiary.migrate_artifacts!()
```

The call is **idempotent and restartable**: rows already moved carry a different `backend`
value and are skipped. If the disk fills up mid-migration, the failing row is left
untouched and the next invocation picks up from there.

```@setup fs
DearDiary.close_database()
DearDiary._DEARDIARY_APICONFIG = nothing
```
