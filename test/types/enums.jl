@testset verbose = true "enums utilities" begin
    @testset verbose = true "convert integer value to status enum" begin
        @test convert(DearDiary.ExperimentStatus, 1) == DearDiary.IN_PROGRESS
        @test convert(DearDiary.ExperimentStatus, 2) == DearDiary.STOPPED
        @test convert(DearDiary.ExperimentStatus, 3) == DearDiary.FINISHED
        @test_throws ArgumentError convert(DearDiary.ExperimentStatus, 4)
    end
end
