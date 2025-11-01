@with_tracking_test_db begin
    @testset verbose = true "user repository" begin
        @testset verbose = true "insert user" begin
            @testset "insert with no existing username" begin
                @test Tracking.insert(
                    Tracking.User,
                    "Missy",
                    "Gala",
                    "missy",
                    "gala",
                ) isa Tuple{Integer,Tracking.Created}
            end

            @testset "insert with existing username" begin
                @test Tracking.insert(
                    Tracking.User,
                    "Missy",
                    "Gala",
                    "missy",
                    "gala",
                ) isa Tuple{Nothing,Tracking.Duplicate}

            end

            @testset "insert with empty username" begin
                @test Tracking.insert(
                    Tracking.User,
                    "Missy",
                    "Gala",
                    "",
                    "gala",
                ) isa Tuple{Nothing,Tracking.Unprocessable}
            end
        end

        @testset verbose = true "fetch user" begin
            @testset "fetch with existing username" begin
                user = Tracking.fetch(Tracking.User, "missy")

                @test user isa Tracking.User
                @test user.id isa Int
                @test user.first_name == "Missy"
                @test user.last_name == "Gala"
                @test user.username == "missy"
                @test user.created_date isa DateTime
            end

            @testset "fetch by id" begin
                username_user = Tracking.fetch(Tracking.User, "missy")
                user = Tracking.fetch(Tracking.User, username_user.id)

                @test user isa Tracking.User
                @test user.id == username_user.id
                @test user.first_name == username_user.first_name
                @test user.last_name == username_user.last_name
                @test user.username == username_user.username
                @test user.created_date isa DateTime
            end


            @testset "query with non-existing username" begin
                @test Tracking.fetch(Tracking.User, "gala") |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            Tracking.insert(Tracking.User, "Gala", "Missy", "gala", "missy")

            users = Tracking.User |> Tracking.fetch_all

            @test users isa Array{Tracking.User,1}
            @test (users |> length) == 3 # Including the default user
        end

        @testset verbose = true "update" begin
            username_user = Tracking.fetch(Tracking.User, "missy")
            @test Tracking.update(
                Tracking.User, username_user.id;
                first_name="Ana",
                last_name=nothing,
            ) isa Tracking.Updated

            user = Tracking.fetch(Tracking.User, "missy")

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete" begin
            user = Tracking.fetch(Tracking.User, "missy")
            @test Tracking.delete(Tracking.User, user.id)
            @test Tracking.fetch(Tracking.User, "missy") |> isnothing
            @test (Tracking.User |> Tracking.fetch_all |> length) == 2 # Including the default user
        end
    end
end
