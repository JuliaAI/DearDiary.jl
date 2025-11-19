push!(LOAD_PATH, "../src/")
using Documenter
using DearDiary

DocMeta.setdocmeta!(DearDiary, :DocTestSetup, :(using DearDiary); recursive=true)

makedocs(;
    modules=[DearDiary],
    sitename="$(DearDiary |> nameof |> String).jl",
    format=Documenter.HTML(;),
    pages=[
        "Home" => "index.md",
        "Tutorial" => "tutorial.md",
        "Index" => "indexes.md",
        "Reference" => [
            "Types" => "reference/types.md",
            "User" => "reference/user.md",
            "Project" => "reference/project.md",
            "User Permission" => "reference/userpermission.md",
            "Experiment" => "reference/experiment.md",
            "Iteration" => "reference/iteration.md",
            "Parameter" => "reference/parameter.md",
            "Metric" => "reference/metric.md",
            "Resource" => "reference/resource.md",
            "Miscellaneous" => "reference/misc.md",
            "REST API" => "reference/api.md",
        ],
    ],
    warnonly=[:cross_references, :missing_docs],
)

deploydocs(; repo="github.com/JuliaAI/DearDiary.jl.git")
