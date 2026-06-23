"""
    S3Store <: AbstractArtifactStore

S3-compatible object-store backend. Speaks the S3 protocol via a minimal hand-rolled
SigV4 signer, so the same struct talks to AWS S3, MinIO, Cloudflare R2, Backblaze B2, or any
endpoint that implements the wire format. Pick the right `endpoint` URL and bucket name.

Path-style addressing is used (`<endpoint>/<bucket>/<key>`) so this works against MinIO out
of the box; AWS S3 still accepts path-style for buckets created before the virtual-hosted
cut-over.

Fields
- `bucket::String`: Target bucket name.
- `endpoint::String`: Scheme + host (+ optional port). Examples:
  `https://s3.us-east-1.amazonaws.com`, `http://localhost:9000` (MinIO).
- `region::String`: Region used in the SigV4 credential scope (e.g. `us-east-1`).
- `access_key::String`, `secret_key::String`: SigV4 credentials.
- `http_transport::Function`: `(method, url, headers, body) -> response`. Defaults to
  [`_default_s3_transport`](@ref). Overridden by tests with a closure that captures the
  request rather than hitting the network.
"""
struct S3Store <: AbstractArtifactStore
    bucket::String
    endpoint::String
    region::String
    access_key::String
    secret_key::String
    http_transport::Function
end

"""
    S3Store(; bucket, endpoint, region, access_key, secret_key, http_transport=_default_s3_transport)

Keyword constructor with a default transport. Tests inject their own transport to avoid
hitting the network.
"""
function S3Store(;
    bucket::AbstractString,
    endpoint::AbstractString,
    region::AbstractString,
    access_key::AbstractString,
    secret_key::AbstractString,
    http_transport::Function=_default_s3_transport,
)::S3Store
    return S3Store(bucket, endpoint, region, access_key, secret_key, http_transport)
end

backend_id(::S3Store)::String = "s3"

const S3_URI_PREFIX = "s3://"

"""
    _default_s3_transport(method, url, headers, body)

Default HTTP transport that hands the request off to `HTTP.request` with
`status_exception=false` so 4xx/5xx responses surface as data, not exceptions.
"""
function _default_s3_transport(
    method::AbstractString,
    url::AbstractString,
    headers::AbstractDict{String,String},
    body::AbstractVector{UInt8},
)
    return HTTP.request(
        method,
        url;
        headers=[k => v for (k, v) in headers],
        body=(Vector{UInt8}(body)),
        status_exception=false,
    )
end

"""
    write_artifact(store::S3Store, data)::ArtifactWriteResult

Upload `data` to `s3://<bucket>/<aa>/<uuid>` via a signed PUT. Each call uses a fresh UUID
so two writes of identical bytes never overwrite each other, mirroring the
[`FilesystemStore`](@ref) deletion-safety contract.
"""
function write_artifact(store::S3Store, data::AbstractVector{UInt8})::ArtifactWriteResult
    id = string(UUIDs.uuid4())
    key = string(id[1:2], '/', id)
    response = _s3_request(store, "PUT", key, Vector{UInt8}(data))
    if response.status >= 400
        throw(
            ErrorException(
                "S3Store PUT failed: HTTP $(response.status): $(response.body |> String)"
            ),
        )
    end
    uri = string(S3_URI_PREFIX, store.bucket, '/', key)
    return ArtifactWriteResult(uri, (length(data)), sha256_hex(data))
end

"""
    read_artifact(store::S3Store, uri, inline)::Vector{UInt8}

Fetch the object identified by an `s3://<bucket>/<key>` URI. `inline` is ignored; the
canonical bytes live in the object store. Raises an [`ErrorException`](@ref) on non-2xx
responses.
"""
function read_artifact(
    store::S3Store, uri::AbstractString, ::Optional{<:AbstractVector{UInt8}}
)::Vector{UInt8}
    key = _key_from_uri(store, uri)
    response = _s3_request(store, "GET", key, UInt8[])
    if response.status >= 400
        throw(
            ErrorException(
                "S3Store GET failed: HTTP $(response.status): $(response.body |> String)"
            ),
        )
    end
    return Vector{UInt8}(response.body)
end

"""
    delete_artifact(store::S3Store, uri)::Bool

Delete the object at `uri`. Returns `true` on both `2xx` and `404` (idempotent delete), and
`false` on any other status, so a caller can log a partial failure without bringing down
the surrounding service-layer operation.
"""
function delete_artifact(store::S3Store, uri::AbstractString)::Bool
    key = _key_from_uri(store, uri)
    response = _s3_request(store, "DELETE", key, UInt8[])
    return response.status < 300 || response.status == 404
end

function _key_from_uri(store::S3Store, uri::AbstractString)::String
    if !startswith(uri, S3_URI_PREFIX)
        throw(ArgumentError("S3Store expects '$S3_URI_PREFIX' URIs, got '$uri'"))
    end
    rest = uri[((length(S3_URI_PREFIX)) + 1):end]
    prefix = string(store.bucket, '/')
    if !startswith(rest, prefix)
        throw(
            ArgumentError("URI bucket does not match store bucket '$(store.bucket)': $uri")
        )
    end
    return rest[((length(prefix)) + 1):end]
end

function _s3_request(
    store::S3Store, method::AbstractString, key::AbstractString, body::Vector{UInt8}
)
    url = string(store.endpoint, '/', store.bucket, '/', key)
    headers = Dict{String,String}()
    sigv4_sign!(
        headers,
        method,
        url,
        body,
        store.region,
        "s3",
        store.access_key,
        store.secret_key,
        now(UTC),
    )
    return store.http_transport(method, url, headers, body)
end

"""
    sigv4_sign!(headers, method, url, body, region, service, access_key, secret_key, ts)

Mutate `headers` so the request is AWS SigV4-signed. After this returns, `headers` carries
the `Host`, `X-Amz-Date`, `X-Amz-Content-Sha256`, and `Authorization` headers that AWS S3
and MinIO expect.

`ts` must be a UTC [`DateTime`](@ref); the timestamp is encoded as ISO 8601 basic format.

This is a minimal implementation: path-style URLs only, no query parameters signed, full
payload sha256 (no `UNSIGNED-PAYLOAD` shortcut). That covers PUT/GET/DELETE/HEAD without
pulling in the full SigV4 surface area.
"""
function sigv4_sign!(
    headers::Dict{String,String},
    method::AbstractString,
    url::AbstractString,
    body::AbstractVector{UInt8},
    region::AbstractString,
    service::AbstractString,
    access_key::AbstractString,
    secret_key::AbstractString,
    ts::DateTime,
)::Nothing
    uri = HTTP.URI(url)
    host = uri.host
    if !(isempty(uri.port))
        host = string(host, ':', uri.port)
    end

    body_hash = sha256_hex(body)
    amz_date = Dates.format(ts, dateformat"yyyymmdd\THHMMSS\Z")
    short_date = Dates.format(ts, dateformat"yyyymmdd")

    headers["Host"] = host
    headers["X-Amz-Date"] = amz_date
    headers["X-Amz-Content-Sha256"] = body_hash

    # Canonical headers: lowercased name, trimmed value, sorted by name.
    canonical_headers_entries = [(lowercase(k), strip(v)) for (k, v) in headers]
    sort!(canonical_headers_entries; by=p -> p[1])
    canonical_headers =
        join(["$(name):$(value)\n" for (name, value) in canonical_headers_entries])
    signed_headers = join([name for (name, _) in canonical_headers_entries], ";")

    canonical_path = (isempty(uri.path)) ? "/" : uri.path
    canonical_request = string(
        method,
        '\n',
        canonical_path,
        '\n',
        # No query parameters in this minimal implementation.
        "",
        '\n',
        canonical_headers,
        '\n',
        signed_headers,
        '\n',
        body_hash,
    )
    canonical_request_hash = sha256_hex(Vector{UInt8}(canonical_request))

    credential_scope = string(short_date, '/', region, '/', service, "/aws4_request")
    string_to_sign = string(
        "AWS4-HMAC-SHA256",
        '\n',
        amz_date,
        '\n',
        credential_scope,
        '\n',
        canonical_request_hash,
    )

    k_secret = Vector{UInt8}(("AWS4" * secret_key))
    k_date = SHA.hmac_sha256(k_secret, Vector{UInt8}(short_date))
    k_region = SHA.hmac_sha256(k_date, Vector{UInt8}(region))
    k_service = SHA.hmac_sha256(k_region, Vector{UInt8}(service))
    k_signing = SHA.hmac_sha256(k_service, Vector{UInt8}("aws4_request"))
    signature = bytes2hex(SHA.hmac_sha256(k_signing, Vector{UInt8}(string_to_sign)))

    authorization = string(
        "AWS4-HMAC-SHA256 ",
        "Credential=",
        access_key,
        "/",
        credential_scope,
        ", ",
        "SignedHeaders=",
        signed_headers,
        ", ",
        "Signature=",
        signature,
    )
    headers["Authorization"] = authorization
    return nothing
end
