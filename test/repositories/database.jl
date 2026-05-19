@testset verbose = true "database utilities" begin
    @testset verbose = true "initialize database" begin
        @testset "with default file name" begin
            DearDiary.initialize_database()

            @test DearDiary.get_database() isa SQLite.DB
            @test DearDiary.get_database().file == "deardiary.db"

            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end

        @testset "with custom file name" begin
            DearDiary.initialize_database(; file_name="custom_deardiary.db")

            @test DearDiary.get_database() isa SQLite.DB
            @test DearDiary.get_database().file == "custom_deardiary.db"

            DearDiary.close_database()
            rm("custom_deardiary.db"; force=true)
        end

        @testset "checking initializatoin" begin
            DearDiary.initialize_database()

            rows = DBInterface.execute(
                DearDiary.get_database(),
                "SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name",
            )

            for row in rows
                @test row isa SQLite.Row
                @test keys(row) == [:name]
                table_names = [
                    ["user"],
                    ["project"],
                    ["user_permission"],
                    ["tag"],
                    ["project_tag"],
                    ["experiment"],
                    ["iteration"],
                    ["parameter"],
                    ["metric"],
                    ["resource"],
                    ["experiment_tag"],
                    ["iteration_tag"],
                    ["model"],
                    ["model_version"],
                    ["schema_migrations"],
                    ["sqlite_sequence"],
                ]
                @test values(row) in table_names
            end
            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end
    end

    @testset verbose = true "migration harness" begin
        @testset "schema_migrations is populated on first init" begin
            DearDiary.initialize_database()

            rows = [
                DearDiary.row_to_dict(r) for r in DBInterface.execute(
                    DearDiary.get_database(),
                    "SELECT version, name FROM schema_migrations ORDER BY version",
                )
            ]

            @test (rows |> length) == (DearDiary.MIGRATIONS |> length)
            @test [row[:version] for row in rows] ==
                  [m.version for m in DearDiary.MIGRATIONS]
            @test [row[:name] for row in rows] ==
                  [m.name for m in DearDiary.MIGRATIONS]

            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end

        @testset "second initialize_database is a no-op" begin
            DearDiary.initialize_database()
            first_count = DearDiary.fetch_count(
                "SELECT COUNT(*) AS count FROM schema_migrations",
            )
            DearDiary.close_database()

            DearDiary.initialize_database()
            second_count = DearDiary.fetch_count(
                "SELECT COUNT(*) AS count FROM schema_migrations",
            )

            @test first_count == second_count
            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end

        @testset "apply_migrations applies pending migrations only" begin
            DearDiary.initialize_database()
            db = DearDiary.get_database()

            # Pretend version 1 was never applied: re-running apply_migrations should
            # restamp it without touching the (now-existent) tables, because every
            # statement in the baseline uses IF NOT EXISTS.
            DBInterface.execute(db, "DELETE FROM schema_migrations")
            DearDiary.apply_migrations(db)

            count = DearDiary.fetch_count(
                "SELECT COUNT(*) AS count FROM schema_migrations",
            )
            @test count == (DearDiary.MIGRATIONS |> length)

            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end
    end

    @testset verbose = true "get database singleton" begin
        @testset "before initialization" begin
            db = DearDiary.get_database()
            @test db |> isnothing
        end

        @testset "after initialization" begin
            DearDiary.initialize_database()

            db = DearDiary.get_database()
            @test db isa SQLite.DB

            @test db === DearDiary.get_database()

            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end
    end
end
