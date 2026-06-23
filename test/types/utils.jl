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

    struct ShowMethodTestType <: DearDiary.ResultType
        a::Int
        b::DateTime
        c::Array{UInt8,1}
    end

    @testset verbose = true "show method for ResultType" begin
        @testset "with UInt8 < 6" begin
            obj = ShowMethodTestType(
                1, DateTime(2025, 11, 02, 0, 0, 0), UInt8[1, 2, 3, 4, 5]
            )
            io = IOBuffer()
            DearDiary.show(io, MIME"text/plain"(), obj)
            output = String(take!(io))

            @test occursin("ShowMethodTestType", output)
            @test occursin("a = 1", output)
            @test occursin("b = 2025-11-02T00:00:00", output)
            @test occursin("c = UInt8[0x01, 0x02, 0x03, 0x04, 0x05]", output)
        end

        @testset "with UInt8 > 6" begin
            obj = ShowMethodTestType(
                1, DateTime(2025, 11, 02, 0, 0, 0), UInt8[1, 2, 3, 4, 5, 6, 7, 8, 9]
            )
            io = IOBuffer()
            DearDiary.show(io, MIME"text/plain"(), obj)
            output = String(take!(io))

            @test occursin("ShowMethodTestType", output)
            @test occursin("a = 1", output)
            @test occursin("b = 2025-11-02T00:00:00", output)
            @test occursin("c = UInt8[0x01, 0x02, 0x03, …, 0x07, 0x08, 0x09]", output)
        end
    end

    @testset verbose = true "show method for array of ResultType" begin
        @testset "with n < 6" begin
            objs = [
                ShowMethodTestType(i, DateTime(2025, 11, 02, 0, 0, 0), UInt8[1, 2, 3]) for
                i in 1:4
            ]
            io = IOBuffer()
            DearDiary.show(io, MIME"text/plain"(), objs)
            output = String(take!(io))

            @test occursin("4-element Vector{ShowMethodTestType}:", output)
            @test !occursin("⋮", output)
        end

        @testset "with n > 6" begin
            objs = [
                ShowMethodTestType(i, DateTime(2025, 11, 02, 0, 0, 0), UInt8[1, 2, 3]) for
                i in 1:10
            ]
            io = IOBuffer()
            DearDiary.show(io, MIME"text/plain"(), objs)
            output = String(take!(io))

            @test occursin("10-element Vector{ShowMethodTestType}:", output)
            @test occursin("⋮", output)
        end
    end

    @testset "show method for creation processes NamedTuple" begin
        creation_result = (id=123, status=DearDiary.Created)
        io = IOBuffer()
        DearDiary.show(io, MIME"text/plain"(), creation_result)
        output = String(take!(io))

        @test "(id = 123, status = DearDiary.Created)" == strip(output)
    end
end
