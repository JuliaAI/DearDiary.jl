@testset verbose = true "load config" begin
    file = create_test_env_file(; host="0.0.0.0")

    @testset "file exists" begin
        config = file |> TrackingAPI.load_config

        @test config.host == "0.0.0.0"
        @test config.port == 9000
        @test config.db_file == "trackingapi_test.db"
        @test config.jwt_secret == "trackingapi_secret"
        @test config.enable_auth == false
    end

    @testset "file does not exist" begin
        if (file |> isfile)
            file |> rm
        end

        config = (file |> TrackingAPI.load_config)
        @test config.host == "localhost"
    end
end
