@with_trackingapi_test_db begin
    @testset verbose = true "user repository" begin
        @testset verbose = true "insert user" begin
            @testset "insert with no existing username" begin
                @test TrackingAPI.insert(TrackingAPI.User, "Missy", "Gala", "missy", "gala") == TrackingAPI.CREATED
            end

            @testset "insert with existing username" begin
                @test TrackingAPI.insert(TrackingAPI.User, "Missy", "Gala", "missy", "gala") == TrackingAPI.DUPLICATE
            end

            @testset "insert with empty username" begin
                @test TrackingAPI.insert(TrackingAPI.User, "Missy", "Gala", "", "gala") == TrackingAPI.UNPROCESSABLE
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
                @test user.created_at isa DateTime
            end

            @testset "fetch by id" begin
                user = TrackingAPI.fetch(TrackingAPI.User, 2)

                @test user isa TrackingAPI.User
                @test user.id == 2
                @test user.first_name == "Missy"
                @test user.last_name == "Gala"
                @test user.username == "missy"
                @test user.created_at isa DateTime
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
            @test TrackingAPI.update(TrackingAPI.User, 2; first_name="Ana", last_name=nothing) == TrackingAPI.UPDATED

            user = TrackingAPI.fetch(TrackingAPI.User, "missy")

            @test user.first_name == "Ana"
            @test user.last_name == "Gala"
        end

        @testset verbose = true "delete" begin
            @test TrackingAPI.delete(TrackingAPI.User, 2)
            @test TrackingAPI.fetch(TrackingAPI.User, "missy") |> isnothing
            @test (TrackingAPI.User |> TrackingAPI.fetch_all |> length) == 2 # Including the default user
        end
    end
end
