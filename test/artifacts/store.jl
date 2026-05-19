@testset verbose = true "artifact store core" begin
    @testset "sha256_hex against known vectors" begin
        # FIPS 180-2 test vectors — same digests every reference implementation produces.
        @test sha256_empty_input() ==
              "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        @test sha256_abc_input() ==
              "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        @test sha256_long_input() ==
              "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"
    end

    @testset "SQLiteStore.write_artifact computes metadata" begin
        store = DearDiary.SQLiteStore()
        result = DearDiary.write_artifact(store, UInt8[0x68, 0x65, 0x6c, 0x6c, 0x6f]) # "hello"

        @test result isa DearDiary.ArtifactWriteResult
        @test result.uri == ""
        @test result.size_bytes == 5
        @test result.content_hash ==
              "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        @test DearDiary.backend_id(store) == "sqlite"
    end

    @testset "sha256_hex matches stdlib for nontrivial input" begin
        bytes = rand(UInt8, 4096)
        @test DearDiary.sha256_hex(bytes) == (bytes |> SHA.sha256 |> bytes2hex)
    end

    @testset "SQLiteStore.read_artifact returns inline bytes" begin
        store = DearDiary.SQLiteStore()
        bytes = UInt8[0xCA, 0xFE, 0xBA, 0xBE]
        @test DearDiary.read_artifact(store, "", bytes) == bytes
    end

    @testset "SQLiteStore.read_artifact rejects missing inline bytes" begin
        store = DearDiary.SQLiteStore()
        @test_throws ArgumentError DearDiary.read_artifact(store, "", nothing)
    end

    @testset "current_artifact_store dispatches via config" begin
        @test DearDiary.current_artifact_store() isa DearDiary.SQLiteStore
        @test DearDiary.artifact_store_for("sqlite") isa DearDiary.SQLiteStore
        # Unknown backends fall back to sqlite with a logged warning.
        @test DearDiary.artifact_store_for("does-not-exist") isa DearDiary.SQLiteStore
    end
end

@with_deardiary_test_db begin
    @testset verbose = true "resource artifact columns populated on create" begin
        user = DearDiary.get_user("default")
        project_id, _ = DearDiary.create_project(user.id, "Artifact Project")
        experiment_id, _ = DearDiary.create_experiment(
            project_id, DearDiary.IN_PROGRESS, "Artifact Experiment",
        )

        payload = UInt8[0x68, 0x65, 0x6c, 0x6c, 0x6f]  # "hello"
        resource_id, _ = DearDiary.create_resource(experiment_id, "test", payload)
        resource = resource_id |> DearDiary.get_resource

        @test resource isa DearDiary.Resource
        @test resource.backend == "sqlite"
        @test resource.uri == ""
        @test resource.size_bytes == 5
        @test resource.content_hash ==
              "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        @test resource.data == payload
    end
end
