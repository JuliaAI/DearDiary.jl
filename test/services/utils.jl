@testset verbose = true "service utilities" begin
    @testset verbose = true "transform object to Dict" begin
        user = DearDiary.User(
            "00000000-0000-0000-0000-000000000001",
            "Missy",
            "Gala",
            "missy",
            "gala",
            DateTime("2021-01-01T00:00:00"),
            false,
        )
        user_dict = DearDiary.Dict(user)

        @test user_dict isa Dict
        @test user_dict[:id] == "00000000-0000-0000-0000-000000000001"
        @test user_dict[:first_name] == "Missy"
        @test user_dict[:last_name] == "Gala"
        @test user_dict[:username] == "missy"
        @test user_dict[:password] == "gala"
        @test user_dict[:created_date] == DateTime("2021-01-01T00:00:00")
        @test user_dict[:is_admin] == false
    end

    @testset verbose = true "compare result type object fields" begin
        user = DearDiary.User(
            "00000000-0000-0000-0000-000000000001",
            "Missy",
            "Gala",
            "missy",
            "gala",
            DateTime("2021-01-01T00:00:00"),
            false,
        )
        @test !(DearDiary.compare_object_fields(
            user; id="00000000-0000-0000-0000-000000000001"
        ))
        @test DearDiary.compare_object_fields(
            user; id="00000000-0000-0000-0000-000000000099"
        )
    end
end
