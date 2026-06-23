# Run the server

## Starting and stopping

Call [`DearDiary.run`](@ref) from a Julia session. It reads an `.env` file in the
current directory by default:

```julia
using DearDiary

DearDiary.run()                         # reads .env
DearDiary.run(; env_file="/path/.env")  # explicit path
```

`run` starts the REST API server (and the embedded dashboard when
`DEARDIARY_ENABLE_UI=true`) as non-blocking background tasks.

To shut down both servers and release the database connection:

```julia
DearDiary.stop()
```

## Configuration reference

All settings are read from the env file at startup. The table below lists every
`DEARDIARY_*` variable, its default, and what it controls.

| Variable | Default | Meaning |
|---|---|---|
| `DEARDIARY_HOST` | `127.0.0.1` | Address the REST API server binds to. |
| `DEARDIARY_PORT` | `9000` | Port the REST API server listens on. |
| `DEARDIARY_DB_FILE` | `deardiary.db` | Path to the DuckDB database file. Created on first run if absent. |
| `DEARDIARY_JWT_SECRET` | `deardiary_secret` | Secret used to sign and verify JWTs. Replace with a strong random value before enabling auth. |
| `DEARDIARY_ENABLE_AUTH` | `false` | Set `true` to require bearer tokens on every request except `POST /auth` and `GET /health`. |
| `DEARDIARY_CORS_ORIGINS` | `*` | Comma-separated list of allowed browser origins. `*` permits any origin. |
| `DEARDIARY_ARTIFACT_BACKEND` | `inline` | Storage backend for artifact bytes: `inline` (stored in the database), `filesystem`, or `s3`. |
| `DEARDIARY_ARTIFACT_FS_ROOT` | `<cwd>/deardiary_artifacts` | Root directory for the `filesystem` backend. Created on first write. Ignored for other backends. |
| `DEARDIARY_ARTIFACT_S3_BUCKET` | _(empty)_ | S3 bucket name. Required for the `s3` backend. |
| `DEARDIARY_ARTIFACT_S3_ENDPOINT` | _(empty)_ | Scheme and host for S3 requests, e.g. `https://s3.us-east-1.amazonaws.com` or `http://localhost:9000` for MinIO. |
| `DEARDIARY_ARTIFACT_S3_REGION` | `us-east-1` | Region used in the SigV4 credential scope. |
| `DEARDIARY_ARTIFACT_S3_ACCESS_KEY` | _(empty)_ | SigV4 access key for the `s3` backend. |
| `DEARDIARY_ARTIFACT_S3_SECRET_KEY` | _(empty)_ | SigV4 secret key for the `s3` backend. |
| `DEARDIARY_ENABLE_UI` | `true` | Set `false` to skip booting the embedded dashboard. The REST API continues to run. |
| `DEARDIARY_UI_HOST` | `127.0.0.1` | Address the dashboard binds to. |
| `DEARDIARY_UI_PORT` | `9001` | Port the dashboard listens on. |

## Example `.env` file

```text
DEARDIARY_HOST=0.0.0.0
DEARDIARY_PORT=9000
DEARDIARY_DB_FILE=/data/deardiary.db
DEARDIARY_ENABLE_AUTH=true
DEARDIARY_JWT_SECRET=replace-with-a-strong-random-secret
DEARDIARY_CORS_ORIGINS=https://app.example.com,https://admin.example.com
DEARDIARY_ARTIFACT_BACKEND=filesystem
DEARDIARY_ARTIFACT_FS_ROOT=/data/artifacts
DEARDIARY_ENABLE_UI=false
```

!!! warning
    When `DEARDIARY_ENABLE_AUTH=true`, `run` will throw an error if
    `DEARDIARY_JWT_SECRET` is still set to the built-in default
    `"deardiary_secret"`. Set a strong, unique secret before enabling auth.
