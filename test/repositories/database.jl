@testset verbose = true "get database" begin
    @testset "check memoization" begin
        db1 = TrackingAPI.get_database()
        db2 = TrackingAPI.get_database()

        @test db1 === db2
    end

    @testset "initialize database" begin
        TrackingAPI.initialize_database()

        rows = DBInterface.execute(TrackingAPI.get_database(),
            "SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name")

        for row in rows
            @test row isa SQLite.Row
            @test keys(row) == [:name]
            @test values(row) in [["user"], ["project"], ["user_project"]]
        end
    end
end
