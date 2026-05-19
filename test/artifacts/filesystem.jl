@testset verbose = true "FilesystemStore" begin
    @testset "round trip via write_artifact / read_artifact" begin
        mktempdir() do root
            store = DearDiary.FilesystemStore(root)
            payload = UInt8[0xCA, 0xFE, 0xBA, 0xBE, 0x01, 0x02, 0x03]

            result = DearDiary.write_artifact(store, payload)

            @test result.uri |> startswith("file://")
            @test result.size_bytes == 7
            @test result.content_hash == (payload |> SHA.sha256 |> bytes2hex)
            @test DearDiary.backend_id(store) == "filesystem"

            path = result.uri[length("file://") + 1:end]
            @test isfile(path)
            @test read(path) == payload

            roundtrip = DearDiary.read_artifact(store, result.uri, nothing)
            @test roundtrip == payload
        end
    end

    @testset "shards each write into a 2-char prefix dir" begin
        mktempdir() do root
            store = DearDiary.FilesystemStore(root)
            result = DearDiary.write_artifact(store, UInt8[0x00])
            path = result.uri[length("file://") + 1:end]
            shard = basename(dirname(path))
            @test length(shard) == 2
            @test joinpath(root, shard) == dirname(path)
        end
    end

    @testset "delete_artifact removes the file and is idempotent" begin
        mktempdir() do root
            store = DearDiary.FilesystemStore(root)
            result = DearDiary.write_artifact(store, UInt8[0xAB, 0xCD])
            path = result.uri[length("file://") + 1:end]

            @test isfile(path)
            @test DearDiary.delete_artifact(store, result.uri)
            @test !isfile(path)
            # Second delete is a no-op success.
            @test DearDiary.delete_artifact(store, result.uri)
        end
    end

    @testset "non-file:// URIs are rejected" begin
        store = DearDiary.FilesystemStore("/tmp")
        @test_throws ArgumentError DearDiary.read_artifact(store, "s3://nope", nothing)
    end
end

@testset verbose = true "FilesystemStore via service layer" begin
    # The offline tests run with `current_artifact_store()` defaulting to SQLite (no
    # _DEARDIARY_APICONFIG). We swap in a fake config pointing at a tempdir, exercise the
    # full create/read/delete path, then restore the prior state.
    mktempdir() do root
        prior_config = DearDiary._DEARDIARY_APICONFIG
        try
            DearDiary._DEARDIARY_APICONFIG = DearDiary.APIConfig(
                "127.0.0.1", UInt16(0), "fs_test.db", "secret", false, ["*"],
                "filesystem", root,
                "", "", "us-east-1", "", "",
            )

            DearDiary.initialize_database(; file_name="fs_test.db")
            try
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "FS Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "FS Experiment",
                )

                payload = UInt8[0x10, 0x20, 0x30, 0x40, 0x50]
                resource_id, status = DearDiary.create_resource(
                    experiment_id, "model.bin", payload,
                )
                @test status === DearDiary.Created

                row = resource_id |> DearDiary.get_resource
                @test row.backend == "filesystem"
                @test row.uri |> startswith("file://")
                @test row.size_bytes == 5
                @test row.content_hash == (payload |> SHA.sha256 |> bytes2hex)
                # Inline `data` is intentionally empty for non-SQLite backends.
                @test (row.data |> isnothing) || (row.data |> isempty)

                # The on-disk file exists and matches the payload.
                path = row.uri[length("file://") + 1:end]
                @test isfile(path)
                @test read(path) == payload

                # read_resource_data dereferences the URI through the store.
                @test DearDiary.read_resource_data(resource_id) == payload

                # Delete cascades to the FS.
                @test DearDiary.delete_resource(resource_id)
                @test !isfile(path)
            finally
                DearDiary.close_database()
                rm("fs_test.db"; force=true)
            end
        finally
            DearDiary._DEARDIARY_APICONFIG = prior_config
        end
    end
end
