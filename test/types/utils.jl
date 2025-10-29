@testset verbose = true "type utilities" begin
    struct TestType <: TrackingAPI.ResultType
        a::Int
        b::String
        c::Float64
    end

    @testset verbose = true "constructing a type from a symbol dictionary" begin
        dict = Dict(:a => 1, :b => "test", :c => 3.14)
        obj = TrackingAPI.type_from_dict(TestType, dict, TrackingAPI.WithSymbolKeys())

        @test obj isa TestType
        @test obj.a == 1
        @test obj.b == "test"
        @test obj.c == 3.14
    end

    @testset verbose = true "constructing a type from a string dictionary" begin
        dict = Dict("a" => 1, "b" => "test", "c" => 3.14)
        obj = TrackingAPI.type_from_dict(TestType, dict, TrackingAPI.WithStringKeys())

        @test obj isa TestType
        @test obj.a == 1
        @test obj.b == "test"
        @test obj.c == 3.14
    end

    @testset verbose = true "handling missing fields" begin
        dict = Dict(:a => 1, :b => "test")

        @test_throws KeyError TrackingAPI.type_from_dict(TestType, dict, TrackingAPI.WithSymbolKeys())
    end

    @testset verbose = true "handling extra fields" begin
        dict = Dict(:a => 1, :b => "test", :c => 3.14, :d => "extra")
        obj = TrackingAPI.type_from_dict(TestType, dict, TrackingAPI.WithSymbolKeys())

        @test obj isa TestType
        @test obj.a == 1
        @test obj.b == "test"
        @test obj.c == 3.14
    end

    @testset verbose = true "base constructor with dict" begin
        dict = Dict(:a => 2, :b => "example", :c => 2.71)
        obj = TestType(dict)

        @test obj isa TestType
        @test obj.a == 2
        @test obj.b == "example"
        @test obj.c == 2.71
    end

    @testset verbose = true "error on invalid field types" begin
        dict = Dict(:a => "not an int", :b => "test", :c => 3.14)

        @test_throws ArgumentError TrackingAPI.type_from_dict(TestType, dict, TrackingAPI.WithSymbolKeys())
    end
end
