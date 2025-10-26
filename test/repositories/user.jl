@with_trackingapi_test_db begin
    @testset verbose = true "user repository" begin
        @testset verbose = true "insert user" begin
            @testset "insert with no existing username" begin
                @test TrackingAPI.insert(TrackingAPI.User, "Missy", "Gala", "missy", "gala") isa Tuple{Integer,TrackingAPI.Created}
            end

            @testset "insert with existing username" begin
                @test TrackingAPI.insert(TrackingAPI.User, "Missy", "Gala", "missy", "gala") isa Tuple{Nothing,TrackingAPI.Duplicate}

            end

            @testset "insert with empty username" begin
                @test TrackingAPI.insert(TrackingAPI.User, "Missy", "Gala", "", "gala") isa Tuple{Nothing,TrackingAPI.Unprocessable}
            end
        end

        @testset verbose = true "fetch user" begin
            @testset "fetch with existing username" begin
                user = TrackingAPI.fetch(TrackingAPI.User, "missy")

                @test user isa TrackingAPI.User
                @test user.id isa Int
                @test user.first_name == "Missy"
                @test user.last_name == "Gala"
                @test user.username == "missy"
                @test user.created_date isa DateTime
            end

            @testset "fetch by id" begin
                username_user = TrackingAPI.fetch(TrackingAPI.User, "missy")
                user = TrackingAPI.fetch(TrackingAPI.User, username_user.id)

                @test user isa TrackingAPI.User
                @test user.id == username_user.id
                @test user.first_name == username_user.first_name
                @test user.last_name == username_user.last_name
                @test user.username == username_user.username
                @test user.created_date isa DateTime
            end


            @testset "query with non-existing username" begin
                @test TrackingAPI.fetch(TrackingAPI.User, "gala") |> isnothing
            end
        end

        @testset verbose = true "fetch all" begin
            TrackingAPI.insert(TrackingAPI.User, "Gala", "Missy", "gala", "missy")

            users = TrackingAPI.User |> TrackingAPI.fetch_all

            @test users isa Array{TrackingAPI.User,1}
            @test (users |> length) == 3 # Including the default user
        end

        @testset verbose = true "update" begin
            username_user = TrackingAPI.fetch(TrackingAPI.User, "missy")
            @test TrackingAPI.update(TrackingAPI.User, username_user.id; first_name="Ana", last_name=nothing) isa TrackingAPI.Updated

            user = TrackingAPI.fetch(TrackingAPI.User, "missy")

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete" begin
            user = TrackingAPI.fetch(TrackingAPI.User, "missy")
            @test TrackingAPI.delete(TrackingAPI.User, user.id)
            @test TrackingAPI.fetch(TrackingAPI.User, "missy") |> isnothing
            @test (TrackingAPI.User |> TrackingAPI.fetch_all |> length) == 2 # Including the default user
        end
    end
end
