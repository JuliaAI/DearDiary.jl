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

        @testset "close_database persists the session before the file is reopened" begin
            file = "deardiary_durability_test.db"
            isfile(file) && rm(file)
            DearDiary.initialize_database(; file_name=file)
            user = DearDiary.get_user_by_username("default")
            project_id, _ = DearDiary.create_project(user.id, "Durable")
            experiment_id, _ = DearDiary.create_experiment(
                project_id, DearDiary.IN_PROGRESS, "E"
            )
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            model_id, _ = DearDiary.create_model(project_id, "forest")
            version_id, _ = DearDiary.create_modelversion(
                model_id, iteration_id, nothing, "v"
            )
            DearDiary.close_database()
            try
                for round in 1:3
                    DearDiary.initialize_database(; file_name=file)
                    if round == 1
                        @test DearDiary.delete_model(model_id)
                        @test DearDiary.delete_experiment(experiment_id)
                        other_id, _ = DearDiary.create_model(project_id, "logreg")
                        @test DearDiary.update_model(
                            other_id, "logreg-renamed", nothing
                        ) === DearDiary.Updated
                    else
                        # Every change of the previous round survived the close.
                        @test isnothing(DearDiary.get_model(model_id))
                        @test isnothing(DearDiary.get_experiment(experiment_id))
                        @test isnothing(DearDiary.get_modelversion(version_id))
                        @test [m.name for m in DearDiary.get_models(project_id)] == ["logreg-renamed"]
                    end
                    DearDiary.close_database()
                    @test !isfile(file * ".wal")
                end
            finally
                DearDiary.close_database()
                rm(file)
            end
        end

        @testset "migration 002 rebuilds the registry tables and keeps their rows" begin
            file = "deardiary_upgrade_test.db"
            isfile(file) && rm(file)
            legacy = DBInterface.connect(DuckDB.DB, file)
            for statement in DearDiary.MIGRATION_001_BASELINE.statements
                DBInterface.execute(legacy, DearDiary.duckdbify(statement))
            end
            DBInterface.execute(
                legacy, DearDiary.duckdbify(DearDiary.SQL_CREATE_SCHEMA_MIGRATIONS)
            )
            DBInterface.execute(
                legacy,
                "INSERT INTO schema_migrations (version, name, applied_at) VALUES (1, 'baseline', '2026-01-01')",
            )
            DBInterface.execute(
                legacy,
                "INSERT INTO project (id, name, created_date) VALUES ('p1', 'Legacy', '2026-01-01')",
            )
            DBInterface.execute(
                legacy,
                "INSERT INTO experiment (id, project_id, status_id, name, created_date) VALUES ('e1', 'p1', 1, 'E', '2026-01-01')",
            )
            DBInterface.execute(
                legacy,
                "INSERT INTO iteration (id, experiment_id, created_date) VALUES ('i1', 'e1', '2026-01-01')",
            )
            DBInterface.execute(
                legacy,
                "INSERT INTO model (id, project_id, name, description, created_date) VALUES ('m1', 'p1', 'forest', 'kept', '2026-01-01')",
            )
            DBInterface.execute(
                legacy,
                "INSERT INTO model_version (id, model_id, version, iteration_id, stage_id, description, created_date) VALUES ('v1', 'm1', 1, 'i1', 3, 'first', '2026-01-01')",
            )
            DBInterface.close!(legacy)
            GC.gc()

            DearDiary.initialize_database(; file_name=file)
            try
                @test DearDiary.applied_versions(DearDiary.get_database()) == Set([1, 2])
                model = DearDiary.get_model("m1")
                @test model.name == "forest"
                @test model.description == "kept"
                versions = DearDiary.get_modelversions("m1")
                @test length(versions) == 1
                @test versions[1].iteration_id == "i1"
                @test versions[1].stage_id == Integer(DearDiary.PRODUCTION)
                # Without the unique constraint, a model with versions can be renamed.
                @test DearDiary.update_model("m1", "forest-renamed", nothing) ===
                    DearDiary.Updated
                @test DearDiary.get_model("m1").name == "forest-renamed"
                @test DearDiary.create_model("p1", "forest-renamed").status ===
                    DearDiary.Duplicate
                @test DearDiary.create_modelversion(
                    "m1", "i1", nothing, "second"
                ).status === DearDiary.Created
                # A migrated file reopens cleanly and does not migrate twice.
                DearDiary.close_database()
                DearDiary.initialize_database(; file_name=file)
                @test DearDiary.applied_versions(DearDiary.get_database()) == Set([1, 2])
                @test length(DearDiary.get_modelversions("m1")) == 2
            finally
                DearDiary.close_database()
                rm(file)
            end
        end
    end
end
