@testset verbose = true "migrate_artifacts!" begin
    @testset "refuses when target is SQLiteStore" begin
        result = mktempdir() do _
            sqlite_store = DearDiary.SQLiteStore()
            DearDiary.migrate_artifacts!(sqlite_store)
        end
        @test result.migrated == 0
        @test result.skipped == 0
        @test result.failed == 0
    end

    @testset "moves sqlite-backed rows to a filesystem target" begin
        mktempdir() do root
            DearDiary.initialize_database(; file_name="migrate_test.db")
            try
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Migrate Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Migrate Experiment",
                )

                # Seed two SQLite-backed resources (the current default for offline tests).
                payload_a = UInt8[0x01, 0x02, 0x03, 0x04]
                payload_b = UInt8[0xAA, 0xBB, 0xCC]
                id_a, _ = DearDiary.create_resource(experiment_id, "a", payload_a)
                id_b, _ = DearDiary.create_resource(experiment_id, "b", payload_b)

                target = DearDiary.FilesystemStore(root)
                result = DearDiary.migrate_artifacts!(target)

                @test result.migrated == 2
                @test result.skipped == 0
                @test result.failed == 0

                migrated_a = DearDiary.get_resource(id_a)
                migrated_b = DearDiary.get_resource(id_b)
                @test migrated_a.backend == "filesystem"
                @test migrated_b.backend == "filesystem"
                @test migrated_a.uri |> startswith("file://")
                @test migrated_b.uri |> startswith("file://")
                @test (migrated_a.data |> isnothing) || (migrated_a.data |> isempty)

                # The bytes on disk match the original payloads.
                path_a = migrated_a.uri[length("file://") + 1:end]
                path_b = migrated_b.uri[length("file://") + 1:end]
                @test read(path_a) == payload_a
                @test read(path_b) == payload_b
                @test migrated_a.content_hash == (payload_a |> SHA.sha256 |> bytes2hex)
                @test migrated_b.content_hash == (payload_b |> SHA.sha256 |> bytes2hex)
            finally
                DearDiary.close_database()
                rm("migrate_test.db"; force=true)
            end
        end
    end

    @testset "second call is a no-op (idempotent)" begin
        mktempdir() do root
            DearDiary.initialize_database(; file_name="migrate_test.db")
            try
                user = DearDiary.get_user("default")
                project_id, _ = DearDiary.create_project(user.id, "Migrate Project")
                experiment_id, _ = DearDiary.create_experiment(
                    project_id, DearDiary.IN_PROGRESS, "Migrate Experiment",
                )
                DearDiary.create_resource(experiment_id, "a", UInt8[0x01])

                target = DearDiary.FilesystemStore(root)
                first = DearDiary.migrate_artifacts!(target)
                second = DearDiary.migrate_artifacts!(target)

                @test first.migrated == 1
                @test second.migrated == 0
            finally
                DearDiary.close_database()
                rm("migrate_test.db"; force=true)
            end
        end
    end
end
