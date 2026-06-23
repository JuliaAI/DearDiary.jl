@testset verbose = true "load config" begin
    file = create_test_env_file(; host="0.0.0.0", port=9000)

    @testset "file exists" begin
        config = DearDiary.load_config(file)

        @test config.host == "0.0.0.0"
        @test config.port == 9000
        @test config.db_file == "deardiary_test.db"
        @test config.jwt_secret == "deardiary_secret"
        @test config.enable_auth == false
    end

    @testset "file does not exist" begin
        if (isfile(file))
            rm(file)
        end

        config = (DearDiary.load_config(file))
        @test config.host == "127.0.0.1"
    end
end

@testset verbose = true "run refuses default JWT secret with auth enabled" begin
    file = create_test_env_file(; enable_auth=true)
    try
        @test_throws ArgumentError DearDiary.run(; env_file=file)
    finally
        isfile(file) && (rm(file))
    end
end
