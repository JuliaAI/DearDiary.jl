@with_deardiary_test_db begin
    @testset verbose = true "repository utils" begin
        @testset verbose = true "insert" begin
            first_user = (
                username="missy",
                password="gala",
                first_name="Missy",
                last_name="Gala",
                created_date=string(now()),
            )
            id, status = DearDiary.insert(DearDiary.SQL_INSERT_USER, first_user)
            @test id isa Integer
            @test status === DearDiary.Created

            second_user = (
                username="gala",
                password="missy",
                first_name="Gala",
                last_name="Missy",
                created_date=string(now()),
            )
            id, status = DearDiary.insert(DearDiary.SQL_INSERT_USER, second_user)
            @test id isa Integer
            @test status === DearDiary.Created
        end

        @testset verbose = true "fetch" begin
            user = DearDiary.fetch(
                DearDiary.SQL_SELECT_USER_BY_USERNAME, (username="missy",)
            )

            @test user isa Dict{Symbol,Any}
            @test user[:id] isa Int
            @test user[:first_name] == "Missy"
        end

        @testset verbose = true "fetch all" begin
            users = DearDiary.fetch_all(DearDiary.SQL_SELECT_USERS)

            @test users isa Array{Dict{Symbol,Any},1}
            @test (length(users)) == 3
        end

        @testset verbose = true "update" begin
            user = DearDiary.User(DearDiary.fetch(DearDiary.SQL_SELECT_USER_BY_ID, (id=2,)))

            @test DearDiary.update(
                DearDiary.SQL_UPDATE_USER, user; first_name="Ana", last_name=nothing
            ) === DearDiary.Updated

            user = DearDiary.fetch(
                DearDiary.SQL_SELECT_USER_BY_USERNAME, (username="missy",)
            )
            @test user[:first_name] == "Ana"
            @test user[:last_name] == "Gala"
        end

        @testset verbose = true "delete" begin
            @test DearDiary.delete(DearDiary.SQL_DELETE_USER, 2)

            @test isnothing(
                DearDiary.fetch(DearDiary.SQL_SELECT_USER_BY_USERNAME, (username="missy",))
            )
        end

        @testset verbose = true "row to dict" begin
            rows = DBInterface.execute(
                DearDiary.get_database(),
                "SELECT table_name AS name FROM information_schema.tables " *
                "WHERE table_schema = 'main' ORDER BY table_name",
            )
            row_dict = DearDiary.row_to_dict(first(Tables.namedtupleiterator(rows)))

            @test row_dict isa Dict
            @test :name in (keys(row_dict))
        end
    end
end
