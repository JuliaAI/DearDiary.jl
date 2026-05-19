@testset verbose = true "S3Store SigV4 signing" begin
    @testset "headers populated with credential scope + signature" begin
        headers = Dict{String,String}()
        body = Vector{UInt8}("hello world")
        ts = DateTime(2026, 5, 14, 12, 0, 0)

        DearDiary.sigv4_sign!(
            headers, "PUT", "http://localhost:9000/my-bucket/aa/bb",
            body, "us-east-1", "s3",
            "AKIDEXAMPLE", "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
            ts,
        )

        @test headers["X-Amz-Date"] == "20260514T120000Z"
        @test headers["X-Amz-Content-Sha256"] == (body |> SHA.sha256 |> bytes2hex)
        @test headers["Host"] == "localhost:9000"
        @test occursin("AWS4-HMAC-SHA256", headers["Authorization"])
        @test occursin("Credential=AKIDEXAMPLE/20260514/us-east-1/s3/aws4_request",
                       headers["Authorization"])
        @test occursin("SignedHeaders=", headers["Authorization"])
        @test occursin("Signature=", headers["Authorization"])
    end

    @testset "signature is deterministic for fixed input" begin
        body = UInt8[0x01, 0x02, 0x03]
        ts = DateTime(2026, 5, 14, 12, 0, 0)

        h1 = Dict{String,String}()
        h2 = Dict{String,String}()
        for h in (h1, h2)
            DearDiary.sigv4_sign!(
                h, "GET", "https://s3.us-east-1.amazonaws.com/bucket/key",
                body, "us-east-1", "s3",
                "key", "secret",
                ts,
            )
        end

        @test h1["Authorization"] == h2["Authorization"]
    end

    @testset "signature changes when payload changes" begin
        ts = DateTime(2026, 5, 14, 12, 0, 0)
        h_a = Dict{String,String}()
        h_b = Dict{String,String}()
        DearDiary.sigv4_sign!(
            h_a, "PUT", "https://s3.example.com/bucket/key",
            UInt8[0x00], "us-east-1", "s3", "key", "secret", ts,
        )
        DearDiary.sigv4_sign!(
            h_b, "PUT", "https://s3.example.com/bucket/key",
            UInt8[0xFF], "us-east-1", "s3", "key", "secret", ts,
        )
        @test h_a["Authorization"] != h_b["Authorization"]
    end
end

@testset verbose = true "S3Store via mocked transport" begin
    # The transport mock captures every request it sees and returns canned responses, so the
    # store can be exercised end-to-end without ever touching the network.
    function make_mock(storage::Dict{String,Vector{UInt8}})
        captured = Tuple[]
        transport = function (method, url, headers, body)
            push!(captured, (method, url, copy(headers), copy(body)))
            # Extract the key from the URL: "<endpoint>/<bucket>/<key>"
            key = url[(findfirst("/bucket/", url) |> last) + 1:end]
            if method == "PUT"
                storage[key] = Vector{UInt8}(body)
                return (status=200, body=UInt8[], headers=Dict{String,String}())
            elseif method == "GET"
                if haskey(storage, key)
                    return (status=200, body=storage[key], headers=Dict{String,String}())
                end
                return (status=404, body=UInt8[], headers=Dict{String,String}())
            elseif method == "DELETE"
                delete!(storage, key)
                return (status=204, body=UInt8[], headers=Dict{String,String}())
            end
            return (status=400, body=UInt8[], headers=Dict{String,String}())
        end
        return transport, captured
    end

    @testset "write_artifact rolls a fresh URI and returns metadata" begin
        storage = Dict{String,Vector{UInt8}}()
        transport, captured = make_mock(storage)
        store = DearDiary.S3Store(;
            bucket="bucket",
            endpoint="https://s3.example.com",
            region="us-east-1",
            access_key="key",
            secret_key="secret",
            http_transport=transport,
        )

        payload = UInt8[0xDE, 0xAD, 0xBE, 0xEF]
        result = DearDiary.write_artifact(store, payload)

        @test result.uri |> startswith("s3://bucket/")
        @test result.size_bytes == 4
        @test result.content_hash == (payload |> SHA.sha256 |> bytes2hex)
        @test (captured |> length) == 1
        method, url, headers, body = captured[1]
        @test method == "PUT"
        @test body == payload
        @test haskey(headers, "Authorization")
        @test haskey(headers, "X-Amz-Date")
        @test haskey(headers, "X-Amz-Content-Sha256")
    end

    @testset "read_artifact issues a signed GET against the URI" begin
        storage = Dict{String,Vector{UInt8}}()
        transport, captured = make_mock(storage)
        store = DearDiary.S3Store(;
            bucket="bucket",
            endpoint="https://s3.example.com",
            region="us-east-1",
            access_key="key",
            secret_key="secret",
            http_transport=transport,
        )

        payload = UInt8[0x10, 0x20, 0x30]
        result = DearDiary.write_artifact(store, payload)

        roundtrip = DearDiary.read_artifact(store, result.uri, nothing)
        @test roundtrip == payload
        @test captured[end][1] == "GET"
    end

    @testset "delete_artifact issues a signed DELETE" begin
        storage = Dict{String,Vector{UInt8}}()
        transport, captured = make_mock(storage)
        store = DearDiary.S3Store(;
            bucket="bucket",
            endpoint="https://s3.example.com",
            region="us-east-1",
            access_key="key",
            secret_key="secret",
            http_transport=transport,
        )

        result = DearDiary.write_artifact(store, UInt8[0x01])
        @test DearDiary.delete_artifact(store, result.uri)
        # The store treats 404 as success too.
        @test DearDiary.delete_artifact(store, result.uri)
        @test captured[end][1] == "DELETE"
    end

    @testset "S3 URI parsing rejects foreign buckets" begin
        store = DearDiary.S3Store(;
            bucket="bucket",
            endpoint="https://s3.example.com",
            region="us-east-1",
            access_key="key",
            secret_key="secret",
            http_transport=(args...) -> error("unreachable"),
        )
        @test_throws ArgumentError DearDiary.read_artifact(
            store, "s3://other-bucket/key", nothing,
        )
        @test_throws ArgumentError DearDiary.read_artifact(store, "file:///x", nothing)
    end
end
