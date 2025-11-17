@with_deardiary_test_db begin
    @testset verbose = true "user repository" begin
        @testset verbose = true "insert user" begin
            @testset "insert with no existing username" begin
                id, status = DearDiary.insert(
                    DearDiary.User,
                    "Missy",
                    "Gala",
                    "missy",
                    "gala",
                )
                @test id isa Integer
                @test status isa DearDiary.Created
            end

            @testset "insert with existing username" begin
                id, status = DearDiary.insert(
                    DearDiary.User,
                    "Missy",
                    "Gala",
                    "missy",
                    "gala",
                )
                @test id |> isnothing
                @test status isa DearDiary.Duplicate
            end

            @testset "insert with empty username" begin
                id, status = DearDiary.insert(
                    DearDiary.User,
                    "Missy",
                    "Gala",
                    "",
                    "gala",
                )
                @test id |> isnothing
                @test status isa DearDiary.Unprocessable
            end
        end

        @testset verbose = true "fetch user" begin
            @testset "fetch with existing username" begin
                user = DearDiary.fetch(DearDiary.User, "missy")

                @test user isa DearDiary.User
                @test user.id isa Int
                @test user.first_name == "Missy"
                @test user.last_name == "Gala"
                @test user.username == "missy"
                @test user.created_date isa DateTime
            end

            @testset "fetch by id" begin
                username_user = DearDiary.fetch(DearDiary.User, "missy")
                user = DearDiary.fetch(DearDiary.User, username_user.id)

                @test user isa DearDiary.User
                @test user.id == username_user.id
                @test user.first_name == username_user.first_name
                @test user.last_name == username_user.last_name
                @test user.username == username_user.username
                @test user.created_date isa DateTime
            end


            @testset "query with non-existing username" begin
                @test DearDiary.fetch(DearDiary.User, "gala") |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            DearDiary.insert(DearDiary.User, "Gala", "Missy", "gala", "missy")

            users = DearDiary.User |> DearDiary.fetch_all

            @test users isa Array{DearDiary.User,1}
            @test (users |> length) == 3 # Including the default user
        end

        @testset verbose = true "update" begin
            username_user = DearDiary.fetch(DearDiary.User, "missy")
            @test DearDiary.update(
                DearDiary.User, username_user.id;
                first_name="Ana",
                last_name=nothing,
            ) isa DearDiary.Updated

            user = DearDiary.fetch(DearDiary.User, "missy")

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete" begin
            user = DearDiary.fetch(DearDiary.User, "missy")
            @test DearDiary.delete(DearDiary.User, user.id)
            @test DearDiary.fetch(DearDiary.User, "missy") |> isnothing
            @test (DearDiary.User |> DearDiary.fetch_all |> length) == 2 # Including the default user
        end
    end
end
