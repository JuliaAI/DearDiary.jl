@testset verbose = true "type utilities" begin
    struct TestType <: DearDiary.ResultType
        a::Int
        b::String
        c::Float64
    end

    @testset verbose = true "constructing a type from a symbol dictionary" begin
        dict = Dict(:a => 1, :b => "test", :c => 3.14)
        obj = DearDiary.type_from_dict(TestType, dict)

        @test obj isa TestType
        @test obj.a == 1
        @test obj.b == "test"
        @test obj.c == 3.14
    end

    @testset verbose = true "constructing a type from a string dictionary" begin
        dict = Dict("a" => 1, "b" => "test", "c" => 3.14)
        obj = DearDiary.type_from_dict(TestType, dict)

        @test obj isa TestType
        @test obj.a == 1
        @test obj.b == "test"
        @test obj.c == 3.14
    end

    @testset verbose = true "handling extra fields" begin
        dict = Dict(:a => 1, :b => "test", :c => 3.14, :d => "extra")
        obj = DearDiary.type_from_dict(TestType, dict)

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

        @test_throws ArgumentError DearDiary.type_from_dict(TestType, dict)
    end

    @testset verbose = true "error in unsupported key type" begin
        dict = Dict(1 => "value1", 2 => "value2")

        @test_throws ArgumentError DearDiary.type_from_dict(TestType, dict)
    end

    @testset verbose = true "error in datetime conversion" begin
        struct DateType <: DearDiary.ResultType
            timestamp::Union{DateTime,Nothing}
        end

        dict = Dict(:timestamp => "invalid date string")

        @test_throws ArgumentError DearDiary.type_from_dict(DateType, dict)
    end
end
