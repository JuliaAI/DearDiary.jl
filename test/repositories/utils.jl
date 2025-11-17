@with_deardiary_test_db begin
    @testset verbose = true "repository utils" begin
        @testset verbose = true "insert" begin
            first_user = (
                username="missy",
                password="gala",
                first_name="Missy",
                last_name="Gala",
                created_date=now(),
            )
            id, status = DearDiary.insert(
                DearDiary.SQL_INSERT_USER,
                first_user,
            )
            @test id isa Integer
            @test status isa DearDiary.Created

            second_user = (
                username="gala",
                password="missy",
                first_name="Gala",
                last_name="Missy",
                created_date=now(),
            )
            id, status = DearDiary.insert(
                DearDiary.SQL_INSERT_USER,
                second_user,
            )
            @test id isa Integer
            @test status isa DearDiary.Created
        end

        @testset verbose = true "fetch" begin
            user = DearDiary.fetch(
                DearDiary.SQL_SELECT_USER_BY_USERNAME,
                (username="missy",),
            )

            @test user isa Dict{Symbol,Any}
            @test user[:id] isa Int
            @test user[:first_name] == "Missy"
        end

        @testset verbose = true "fetch all" begin
            users = DearDiary.SQL_SELECT_USERS |> DearDiary.fetch_all

            @test users isa Array{Dict{Symbol,Any},1}
            @test (users |> length) == 3
        end

        @testset verbose = true "update" begin
            user = DearDiary.fetch(
                DearDiary.SQL_SELECT_USER_BY_ID,
                (id=2,),
            ) |> DearDiary.User

            @test DearDiary.update(
                DearDiary.SQL_UPDATE_USER, user;
                first_name="Ana",
                last_name=nothing,
            ) isa DearDiary.Updated

            user = DearDiary.fetch(
                DearDiary.SQL_SELECT_USER_BY_USERNAME,
                (username="missy",),
            )
            @test user[:first_name] == "Ana"
            @test user[:last_name] == "Gala"
        end

        @testset verbose = true "delete" begin
            @test DearDiary.delete(DearDiary.SQL_DELETE_USER, 2)

            @test DearDiary.fetch(
                DearDiary.SQL_SELECT_USER_BY_USERNAME,
                (username="missy",),
            ) |> isnothing
        end

        @testset verbose = true "row to dict" begin
            rows = DBInterface.execute(
                DearDiary.get_database(),
                "SELECT name FROM sqlite_schema WHERE type='table' ORDER BY name",
            )
            row_dict = rows |> first |> DearDiary.Dict

            @test row_dict isa Dict
            @test :name in (row_dict |> keys)
        end
    end
end
