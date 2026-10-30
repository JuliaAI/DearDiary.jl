@testset verbose = true "type display" begin
    date = DateTime(2025, 11, 2, 0, 0, 0)
    iteration_id = "264118c0-ba2f-4ebc-9cfa-628c5d1c6f6a"
    metric = DearDiary.Metric("m-1", iteration_id, "loss", 0.5, 1, date)
    plain(x) = repr(MIME"text/plain"(), x)

    @testset verbose = true "one-line form" begin
        @test repr(metric) == "Metric(loss = 0.5, step = 1)"
        @test repr(DearDiary.Parameter("p-1", iteration_id, "max_depth", "7")) ==
            "Parameter(max_depth = \"7\")"
        @test repr(DearDiary.Project("p-1", "Iris", "", date)) == "Project(\"Iris\")"
        @test repr(DearDiary.Experiment("e-1", "p-1", 1, "Sweep", "", date, nothing)) ==
            "Experiment(\"Sweep\", IN_PROGRESS)"
        @test repr(
            DearDiary.Iteration(
                iteration_id,
                "e-1",
                "",
                date,
                nothing,
                nothing,
                3,
                "",
                "",
                "",
                false,
                "",
                "",
                "",
            ),
        ) == "Iteration(264118c0…, FAILED)"
        @test repr(DearDiary.User("u-1", "", "", "default", "hash", date, true)) ==
            "User(\"default\", admin)"
        @test repr(DearDiary.UserResponse("u-2", "", "", "jdoe", date, false)) ==
            "UserResponse(\"jdoe\")"
        @test repr(
            DearDiary.UserPermission("up-1", "u-2", "p-1", false, true, true, false)
        ) == "UserPermission(read, update)"
        @test repr(
            DearDiary.UserPermission("up-2", "u-2", "p-1", false, false, false, false)
        ) == "UserPermission(no access)"
        @test repr(
            DearDiary.Resource(
                "r-1",
                "e-1",
                "model.jls",
                "",
                nothing,
                date,
                nothing,
                "filesystem",
                "file:///tmp/model.jls",
                1536,
                "",
            ),
        ) == "Resource(\"model.jls\", filesystem, 1.5 KB)"
        @test repr(DearDiary.Tag("t-1", "tabular")) == "Tag(\"tabular\")"
        @test repr(DearDiary.Model("mo-1", "p-1", "iris", "", date, nothing)) ==
            "Model(\"iris\")"
        @test repr(
            DearDiary.ModelVersion(
                "mv-1", "mo-1", 3, iteration_id, nothing, 3, "", date, nothing
            ),
        ) == "ModelVersion(3, PRODUCTION)"
        @test repr(DearDiary.PaginatedResponse([metric], 135, 20, 40)) ==
            "PaginatedResponse(1 of 135, offset 40)"
        # An out-of-range id prints as the bare number instead of throwing.
        @test repr(DearDiary.Experiment("e-2", "p-1", 9, "Odd", "", date, nothing)) ==
            "Experiment(\"Odd\", 9)"
        @test "$(metric)" == "Metric(loss = 0.5, step = 1)"
    end

    @testset verbose = true "detailed form" begin
        output = plain(metric)
        @test startswith(output, "Metric(loss = 0.5, step = 1)\n")
        @test occursin("\n  iteration_id  \"$(iteration_id)\"", output)
        @test occursin("\n  recorded_at   2025-11-02T00:00:00", output)

        experiment = DearDiary.Experiment("e-1", "p-1", 2, "Sweep", "", date, nothing)
        @test occursin("\n  status_id     2 (STOPPED)", plain(experiment))
        @test occursin("\n  end_date      nothing", plain(experiment))

        user = DearDiary.User("u-1", "", "", "default", "secret-hash", date, true)
        @test !occursin("password", plain(user))
        @test !occursin("secret-hash", plain(user))

        manifest = join(["line $(i)" for i in 1:312], "\n") * "\n"
        iteration = DearDiary.Iteration(
            iteration_id,
            "e-1",
            "x"^80,
            date,
            nothing,
            nothing,
            1,
            "",
            "1.12.1",
            "",
            false,
            "",
            "",
            manifest,
        )
        output = plain(iteration)
        @test occursin("manifest_toml        \"line 1\" (312 lines)", output)
        @test occursin("notes                \"$("x"^59)…\"", output)

        resource = DearDiary.Resource(
            "r-1", "e-1", "data.bin", "", UInt8[1, 2, 3], date, nothing, "inline", "", 3, ""
        )
        @test occursin("\n  data           3 B", plain(resource))

        page = DearDiary.PaginatedResponse([metric, metric], 2, 20, 0)
        @test plain(page) ==
            "PaginatedResponse(2 of 2, offset 0)\n" *
              "  Metric(loss = 0.5, step = 1)\n" *
              "  Metric(loss = 0.5, step = 1)"
    end

    @testset verbose = true "vectors" begin
        metrics = [
            DearDiary.Metric("m-$(i)", iteration_id, "loss", 1 / i, i, date) for i in 1:50
        ]
        output = plain(metrics[1:2])
        @test output ==
            "2-element Vector{DearDiary.Metric}:\n" *
              " Metric(loss = 1.0, step = 1)\n" *
              " Metric(loss = 0.5, step = 2)"

        limited = sprint(
            show,
            MIME"text/plain"(),
            metrics;
            context=(:limit => true, :displaysize => (10, 80)),
        )
        @test occursin("⋮", limited)
        @test length(split(limited, '\n')) <= 10

        @test occursin("view(", plain(view(metrics, 1:2)))
    end

    @testset verbose = true "create results" begin
        CreateResult = @NamedTuple{id::DearDiary.Optional{String}, status::DataType}
        @test plain(CreateResult(("abc", DearDiary.Created))) ==
            "(id = \"abc\", status = DearDiary.Created)"
        @test plain(CreateResult((nothing, DearDiary.Unprocessable))) ==
            "(id = nothing, status = DearDiary.Unprocessable)"
        # Other named tuples keep Base's display.
        @test plain((a=1, b="x")) == "(a = 1, b = \"x\")"
    end

    @testset verbose = true "Tables.jl" begin
        metrics = [
            DearDiary.Metric("m-$(i)", iteration_id, "loss", 1 / i, i, date) for i in 1:3
        ]
        @test Tables.istable(metrics)
        columns = Tables.columntable(metrics)
        @test keys(columns) == (:id, :iteration_id, :key, :value, :step, :recorded_at)
        @test columns.value == [1.0, 0.5, 1 / 3]
        schema = Tables.schema(Tables.rows(metrics))
        @test schema.names == fieldnames(DearDiary.Metric)
        @test schema.types == fieldtypes(DearDiary.Metric)
        @test isnothing(Tables.schema(DearDiary.ResultType[metric]))
    end
end
