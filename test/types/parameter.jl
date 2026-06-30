@testset verbose = true "parameter type custom constructor" begin
    @testset verbose = true "constructing Parameter with Real value" begin
        param = DearDiary.Parameter(
            "00000000-0000-0000-0000-000000000001",
            "00000000-0000-0000-0000-000000000002",
            "learning_rate",
            0.01,
        )

        @test param isa DearDiary.Parameter
        @test param.value == "0.01"
    end

    @testset verbose = true "constructing ParameterCreatePayload with Real value" begin
        payload = DearDiary.ParameterCreatePayload("batch_size", 32.55)

        @test payload isa DearDiary.ParameterCreatePayload
        @test payload.value == "32.55"
    end

    @testset verbose = true "constructing ParameterUpdatePayload with Real value" begin
        payload = DearDiary.ParameterUpdatePayload(nothing, 0.1)

        @test payload isa DearDiary.ParameterUpdatePayload
        @test payload.value == "0.1"
    end
end
