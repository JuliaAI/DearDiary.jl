@with_trackingapi_test_db begin
    @testset verbose = true "repository utils" begin
        @testset verbose = true "insert" begin
            @test TrackingAPI.insert(TrackingAPI.SQL_INSERT_USER, (username="missy", password="gala", first_name="Missy", last_name="Gala", created_date=now())) isa Tuple{Integer,TrackingAPI.Created}
            @test TrackingAPI.insert(TrackingAPI.SQL_INSERT_USER, (username="gala", password="missy", first_name="Gala", last_name="Missy", created_date=now())) isa Tuple{Integer,TrackingAPI.Created}
        end

        @testset verbose = true "fetch" begin
            user = TrackingAPI.fetch(TrackingAPI.SQL_SELECT_USER_BY_USERNAME, (username="missy",))

            @test user isa Dict{Symbol,Any}
            @test user[:id] isa Int
            @test user[:first_name] == "Missy"
        end

        @testset verbose = true "fetch all" begin
            users = TrackingAPI.SQL_SELECT_USERS |> TrackingAPI.fetch_all

            @test users isa Array{Dict{Symbol,Any},1}
            @test (users |> length) == 3
        end

        @testset verbose = true "update" begin
            user = TrackingAPI.fetch(TrackingAPI.SQL_SELECT_USER_BY_ID, (id=2,)) |> TrackingAPI.User

            @test TrackingAPI.update(TrackingAPI.SQL_UPDATE_USER, user; first_name="Ana", last_name=nothing) isa TrackingAPI.Updated

            user = TrackingAPI.fetch(TrackingAPI.SQL_SELECT_USER_BY_USERNAME, (username="missy",))
            @test user[:first_name] == "Ana"
            @test user[:last_name] == "Gala"
        end

        @testset verbose = true "delete" begin
            @test TrackingAPI.delete(TrackingAPI.SQL_DELETE_USER, 2)

            @test TrackingAPI.fetch(TrackingAPI.SQL_SELECT_USER_BY_USERNAME, (username="missy",)) |> isnothing
        end

        @testset verbose = true "row to dict" begin
            rows = DBInterface.execute(TrackingAPI.get_database(),
                "SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name")
            row_dict = rows |> first |> TrackingAPI.Dict

            @test row_dict isa Dict
            @test :name in (row_dict |> keys)
        end
    end
end
