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
                    ["sqlite_sequence"],
                ]
                @test values(row) in table_names
            end
            DearDiary.close_database()
            rm("deardiary.db"; force=true)
        end
    end

    @testset verbose = true "get database singleton" begin
        @testset "before initialization" begin
            db = DearDiary.get_database()
            @test db === nothing
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
