# S3 artifact storage

For multi-machine deployments or large checkpoints you want artifact bytes living in an
object store rather than on a single server's disk. DearDiary's [`DearDiary.S3Store`](@ref)
backend speaks the S3 wire protocol via a built-in SigV4 signer, so the same struct talks
to AWS S3, MinIO, Cloudflare R2, Backblaze B2, or any S3-compatible service — pick the
right `endpoint` URL and bucket name.

Path-style addressing is used (`<endpoint>/<bucket>/<key>`), so this works against MinIO
out of the box and against AWS S3 buckets created before the virtual-hosted-style cutover.

## Configuration for AWS S3

```text
DEARDIARY_ARTIFACT_BACKEND=s3
DEARDIARY_ARTIFACT_S3_BUCKET=my-deardiary-bucket
DEARDIARY_ARTIFACT_S3_ENDPOINT=https://s3.us-east-1.amazonaws.com
DEARDIARY_ARTIFACT_S3_REGION=us-east-1
DEARDIARY_ARTIFACT_S3_ACCESS_KEY=AKIA...
DEARDIARY_ARTIFACT_S3_SECRET_KEY=...
```

The bucket must already exist; DearDiary does not create buckets, and IAM rights must
include `s3:PutObject`, `s3:GetObject`, and `s3:DeleteObject` on the bucket.

## Configuration for a local MinIO

Run MinIO in Docker:

```sh
docker run --rm -p 9000:9000 -p 9001:9001 \
    -e MINIO_ROOT_USER=minioadmin \
    -e MINIO_ROOT_PASSWORD=minioadmin \
    minio/minio server /data --console-address ":9001"
```

Create the bucket via the MinIO web console at `http://localhost:9001` (or with
`mc mb local/deardiary` if you have the MinIO client installed), then point DearDiary at
it:

```text
DEARDIARY_ARTIFACT_BACKEND=s3
DEARDIARY_ARTIFACT_S3_BUCKET=deardiary
DEARDIARY_ARTIFACT_S3_ENDPOINT=http://localhost:9000
DEARDIARY_ARTIFACT_S3_REGION=us-east-1
DEARDIARY_ARTIFACT_S3_ACCESS_KEY=minioadmin
DEARDIARY_ARTIFACT_S3_SECRET_KEY=minioadmin
```

## Layout in the bucket

Each artifact is written to `s3://<bucket>/<aa>/<uuid>`. Like the
[`DearDiary.FilesystemStore`](@ref) backend, paths are UUID-keyed (not content-hashed) so
identical payloads from two writes never collide, and deleting one [`Resource`](@ref)
cannot break another.

## Using the backend

Once the env is in place, the rest of the code is identical to the SQLite-backed flow —
the artifact store layer is transparent to the service layer.

### Start the server

In one Julia process, point DearDiary at the `.env` file and start the API server. The
default `DearDiary.run` is asynchronous, so the REPL stays interactive after the server
is up:

```julia
using DearDiary
DearDiary.run(; env_file=".env")
```

The server binds to `127.0.0.1:9000` unless `DEARDIARY_HOST` / `DEARDIARY_PORT` are set in
the `.env`. Keep this REPL running.

### Connect and upload from a training script

In another Julia session — typically your training script on a different machine — connect
to the server and write artifacts the same way you would against any other backend. The
bytes go straight to the bucket; the resource row records only the metadata + URI.

```julia
using DearDiary

client = DearDiary.connect("http://127.0.0.1:9000"; username="default", password="default")

project_id = create_project(client, "S3-backed project")
experiment_id = create_experiment(client, project_id, DearDiary.IN_PROGRESS, "Sweep")

iteration_id = with_iteration(client, experiment_id) do iter
    create_metric(client, iter.id, "accuracy", 0.97)
    iter.id
end

bytes = read("/path/to/checkpoint.bin")
resource_id = create_resource(client, experiment_id, "checkpoint.bin", bytes)

@assert read_resource_data(client, resource_id) == bytes
```

Replace `127.0.0.1:9000` with the server's externally reachable address when running on a
different machine, and replace the `default` / `default` credentials with a real user that
you have created via [`create_user`](@ref).

## Migrating from another backend

After flipping `DEARDIARY_ARTIFACT_BACKEND` to `s3`, move existing rows over:

```julia
using DearDiary
DearDiary.run(; env_file=".env")
DearDiary.migrate_artifacts!()
```

Per-row failures (network blip, AWS 503, etc.) are logged and skipped — the offending row
keeps its `backend = "sqlite"` and is retried on the next invocation. Already-migrated rows
are detected by their `backend` field and skipped, so re-running the function picks up
where it stopped.

## Cost and operational notes

- Every read goes through `s3:GetObject`. Aggressive readers (e.g. a serving layer that
  reloads a model on every request) should cache locally; the metadata `content_hash` field
  makes a "fetch only if changed" pattern straightforward.
- The on-write hash is computed in-process, then included in the request as the
  `X-Amz-Content-Sha256` header. Bytes are never written to local disk en route.
- Deletes via `delete_resource` issue a single `s3:DeleteObject`. There is no archival or
  soft-delete behaviour — drop and you lose it. If your bucket has versioning enabled, the
  delete becomes a tombstone instead.
