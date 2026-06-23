@testset verbose = true "database utilities" begin
    @testset verbose = true "initialize database" begin
        @testset "with default file name" begin
            DearDiary.initialize_database()

            @test DearDiary.get_database() isa DuckDB.DB
            @test isfile("deardiary.db")

            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end

        @testset "with custom file name" begin
            DearDiary.initialize_database(; file_name="custom_deardiary.db")

            @test DearDiary.get_database() isa DuckDB.DB
            @test isfile("custom_deardiary.db")

            DearDiary.close_database()
            rm("custom_deardiary.db"; force=true)
        end

        @testset "checking initialization" begin
            DearDiary.initialize_database()

            rows = DearDiary.fetch_all(
                "SELECT table_name AS name FROM information_schema.tables " *
                "WHERE table_schema = 'main' ORDER BY table_name",
            )
            table_names = Set(row[:name] for row in rows)

            @test table_names == Set([
                "user",
                "project",
                "user_permission",
                "experiment",
                "iteration",
                "parameter",
                "metric",
                "resource",
                "tag",
                "project_tag",
                "experiment_tag",
                "iteration_tag",
                "model",
                "model_version",
                "schema_migrations",
            ])

            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end
    end

    @testset verbose = true "migration harness" begin
        @testset "schema_migrations is populated on first init" begin
            DearDiary.initialize_database()

            rows = DearDiary.fetch_all(
                "SELECT version, name FROM schema_migrations ORDER BY version"
            )

            @test (length(rows)) == (length(DearDiary.MIGRATIONS))
            @test [row[:version] for row in rows] == [m.version for m in DearDiary.MIGRATIONS]
            @test [row[:name] for row in rows] == [m.name for m in DearDiary.MIGRATIONS]

            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end

        @testset "second initialize_database is a no-op" begin
            DearDiary.initialize_database()
            first_count = DearDiary.fetch_count(
                "SELECT COUNT(*) AS count FROM schema_migrations"
            )
            DearDiary.close_database()

            DearDiary.initialize_database()
            second_count = DearDiary.fetch_count(
                "SELECT COUNT(*) AS count FROM schema_migrations"
            )

            @test first_count == second_count
            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end

        @testset "apply_migrations applies pending migrations only" begin
            DearDiary.initialize_database()
            db = DearDiary.get_database()

            # Pretend the baseline was never applied: re-running apply_migrations should
            # restamp it without touching the (now-existent) tables, because every
            # statement in the baseline uses IF NOT EXISTS.
            DBInterface.execute(db, "DELETE FROM schema_migrations")
            DearDiary.apply_migrations(db)

            count = DearDiary.fetch_count("SELECT COUNT(*) AS count FROM schema_migrations")
            @test count == (length(DearDiary.MIGRATIONS))

            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end
    end

    @testset verbose = true "get database singleton" begin
        @testset "before initialization" begin
            db = DearDiary.get_database()
            @test isnothing(db)
        end

        @testset "after initialization" begin
            DearDiary.initialize_database()

            db = DearDiary.get_database()
            @test db isa DuckDB.DB

            @test db === DearDiary.get_database()

            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end
    end
end
