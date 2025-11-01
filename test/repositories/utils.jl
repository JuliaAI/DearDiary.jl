@with_tracking_test_db begin
    @testset verbose = true "repository utils" begin
        @testset verbose = true "insert" begin
            first_user = (
                username="missy",
                password="gala",
                first_name="Missy",
                last_name="Gala",
                created_date=now(),
            )
            @test Tracking.insert(
                Tracking.SQL_INSERT_USER,
                first_user,
            ) isa Tuple{Integer,Tracking.Created}
            second_user = (
                username="gala",
                password="missy",
                first_name="Gala",
                last_name="Missy",
                created_date=now(),
            )
            @test Tracking.insert(
                Tracking.SQL_INSERT_USER,
                second_user,
            ) isa Tuple{Integer,Tracking.Created}
        end

        @testset verbose = true "fetch" begin
            user = Tracking.fetch(
                Tracking.SQL_SELECT_USER_BY_USERNAME,
                (username="missy",),
            )

            @test user isa Dict{Symbol,Any}
            @test user[:id] isa Int
            @test user[:first_name] == "Missy"
        end

        @testset verbose = true "fetch all" begin
            users = Tracking.SQL_SELECT_USERS |> Tracking.fetch_all

            @test users isa Array{Dict{Symbol,Any},1}
            @test (users |> length) == 3
        end

        @testset verbose = true "update" begin
            user = Tracking.fetch(
                Tracking.SQL_SELECT_USER_BY_ID,
                (id=2,),
            ) |> Tracking.User

            @test Tracking.update(
                Tracking.SQL_UPDATE_USER, user;
                first_name="Ana",
                last_name=nothing,
            ) isa Tracking.Updated

            user = Tracking.fetch(
                Tracking.SQL_SELECT_USER_BY_USERNAME,
                (username="missy",),
            )
            @test user[:first_name] == "Ana"
            @test user[:last_name] == "Gala"
        end

        @testset verbose = true "delete" begin
            @test Tracking.delete(Tracking.SQL_DELETE_USER, 2)

            @test Tracking.fetch(
                Tracking.SQL_SELECT_USER_BY_USERNAME,
                (username="missy",),
            ) |> isnothing
        end

        @testset verbose = true "row to dict" begin
            rows = DBInterface.execute(
                Tracking.get_database(),
                "SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name",
            )
            row_dict = rows |> first |> Tracking.Dict

            @test row_dict isa Dict
            @test :name in (row_dict |> keys)
        end
    end
end
