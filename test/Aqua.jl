using Aqua

@testset "Aqua.jl" begin
    DearDiary |> Aqua.test_all
end
