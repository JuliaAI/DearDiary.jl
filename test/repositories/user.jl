using UUIDs

@with_deardiary_test_db begin
    @testset verbose = true "user repository" begin
        @testset "default user id is a valid UUID" begin
            default_user = DearDiary.get_user_by_username("default")
            @test UUIDs.UUID(default_user.id) isa UUIDs.UUID
        end

        @testset verbose = true "insert user" begin
            @testset "insert with no existing username" begin
                id, status = DearDiary.insert(
                    DearDiary.User, "Missy", "Gala", "missy", "gala"
                )
                @test id isa String
                @test !isempty(id)
                @test status === DearDiary.Created
            end

            @testset "insert with existing username" begin
                id, status = DearDiary.insert(
                    DearDiary.User, "Missy", "Gala", "missy", "gala"
                )
                @test isnothing(id)
                @test status === DearDiary.Duplicate
            end

            @testset "insert with empty username" begin
                id, status = DearDiary.insert(DearDiary.User, "Missy", "Gala", "", "gala")
                @test isnothing(id)
                @test status === DearDiary.Unprocessable
            end
        end

        @testset verbose = true "fetch user" begin
            @testset "fetch with existing username" begin
                user = DearDiary.fetch_by_username(DearDiary.User, "missy")

                @test user isa DearDiary.User
                @test user.id isa String
                @test !isempty(user.id)
                @test user.first_name == "Missy"
                @test user.last_name == "Gala"
                @test user.username == "missy"
                @test user.created_date isa DateTime
            end

            @testset "fetch by id" begin
                username_user = DearDiary.fetch_by_username(DearDiary.User, "missy")
                user = DearDiary.fetch(DearDiary.User, username_user.id)

                @test user isa DearDiary.User
                @test user.id == username_user.id
                @test user.first_name == username_user.first_name
                @test user.last_name == username_user.last_name
                @test user.username == username_user.username
                @test user.created_date isa DateTime
            end

            @testset "query with non-existing username" begin
                @test isnothing(DearDiary.fetch_by_username(DearDiary.User, "gala"))
            end
        end

        @testset verbose = true "fetch all" begin
            DearDiary.insert(DearDiary.User, "Gala", "Missy", "gala", "missy")

            users = DearDiary.fetch_all(DearDiary.User)

            @test users isa Array{DearDiary.User,1}
            @test (length(users)) == 3 # Including the default user
        end

        @testset verbose = true "update" begin
            username_user = DearDiary.fetch_by_username(DearDiary.User, "missy")
            @test DearDiary.update(
                DearDiary.User, username_user.id; first_name="Ana", last_name=nothing
            ) === DearDiary.Updated

            user = DearDiary.fetch_by_username(DearDiary.User, "missy")

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete" begin
            user = DearDiary.fetch_by_username(DearDiary.User, "missy")
            @test DearDiary.delete(DearDiary.User, user.id)
            @test isnothing(DearDiary.fetch_by_username(DearDiary.User, "missy"))
            @test (length(DearDiary.fetch_all(DearDiary.User))) == 2 # Including the default user
        end
    end
end
