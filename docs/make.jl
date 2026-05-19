using Pkg
# Pin the docs environment to the local DearDiary checkout. Without this the docs/
# Manifest can pin a stale registered version (the bug that surfaced as a wall of
# "undefined binding" errors against symbols added since the last release), and
# `julia --project=docs docs/make.jl` diverges from what the CI workflow does.
Pkg.develop(PackageSpec(path=dirname(@__DIR__)))
Pkg.instantiate()

using Documenter
using DearDiary

DocMeta.setdocmeta!(DearDiary, :DocTestSetup, :(using DearDiary); recursive=true)

makedocs(;
    modules=[DearDiary],
    sitename="$(DearDiary |> nameof |> String).jl",
    format=Documenter.HTML(;),
    pages=[
        "Home" => "index.md",
        "Tutorial" => [
            "Quickstart" => "tutorial.md",
            "Filesystem artifact storage" => "tutorial/filesystem_artifacts.md",
            "S3 artifact storage" => "tutorial/s3_artifacts.md",
            "Model registry" => "tutorial/model_registry.md",
        ],
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
            "Artifact Storage" => "reference/artifacts.md",
            "Model" => "reference/model.md",
            "Model Version" => "reference/modelversion.md",
            "Miscellaneous" => "reference/misc.md",
            "REST API" => "reference/api.md",
            "Client" => "reference/client.md",
            "Migrations" => "reference/migrations.md",
        ],
    ],
    warnonly=[:cross_references, :missing_docs],
)

deploydocs(; repo="github.com/JuliaAI/DearDiary.jl.git")
