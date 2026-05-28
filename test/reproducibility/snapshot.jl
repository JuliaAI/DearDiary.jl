@testset verbose = true "capture_environment" begin
    @testset "captures julia version and entrypoint override" begin
        snapshot = DearDiary.capture_environment(; entrypoint="my_script.jl")

        @test snapshot isa DearDiary.EnvironmentSnapshot
        @test snapshot.julia_version == (VERSION |> string)
        @test snapshot.entrypoint == "my_script.jl"
    end

    @testset "captures git state when run inside the repository" begin
        snapshot = DearDiary.capture_environment()

        # The test suite always runs against the live working tree, which is a git repo,
        # so we expect a non-empty SHA. We don't assert any specific hash — those change
        # per commit.
        @test snapshot.git_sha |> !isempty
        @test (snapshot.git_sha |> length) == 40
    end

    @testset "captures project + manifest toml as strings" begin
        snapshot = DearDiary.capture_environment()

        # `Pkg.test` resolves into a temporary sandbox project, so the exact contents
        # we'll see here depend on the test runner. Assert only the shape; the
        # `snapshot_environment!` / `restore` round-trip below exercises full data flow.
        @test snapshot.project_toml isa String
        @test snapshot.manifest_toml isa String
    end

    @testset "degrades gracefully outside a git repo" begin
        # `mktempdir` lives under /tmp and has no `.git` walking upward (or, if a parent
        # of /tmp happens to be a git repo, LibGit2 still finds it; that's OK — we're
        # really exercising the no-crash path here).
        prior_cwd = pwd()
        try
            cd(mktempdir())
            @test DearDiary.capture_environment() isa DearDiary.EnvironmentSnapshot
        finally
            cd(prior_cwd)
        end
    end
end

@with_deardiary_test_db begin
    @testset verbose = true "snapshot_environment! persists to iteration row" begin
        user = DearDiary.get_user("default")
        project_id, _ = DearDiary.create_project(user.id, "Repro Project")
        experiment_id, _ = DearDiary.create_experiment(
            project_id, DearDiary.IN_PROGRESS, "Repro Experiment",
        )
        iteration_id, _ = DearDiary.create_iteration(experiment_id)

        # Snapshot the live process state into the new iteration.
        result = DearDiary.snapshot_environment!(iteration_id; entrypoint="run.jl")
        @test result === DearDiary.Updated

        iteration = iteration_id |> DearDiary.get_iteration
        @test iteration.julia_version == (VERSION |> string)
        @test iteration.entrypoint == "run.jl"
        @test (iteration.git_sha |> length) == 40
        @test iteration.project_toml isa String
        @test iteration.manifest_toml isa String
    end

    @testset verbose = true "snapshot_environment! rejects missing iteration" begin
        @test DearDiary.snapshot_environment!(9999) === DearDiary.Unprocessable
    end

    @testset verbose = true "with_iteration auto-snapshots driver but not children" begin
        user = DearDiary.get_user("default")
        project_id, _ = DearDiary.create_project(user.id, "Repro Auto Project")
        experiment_id, _ = DearDiary.create_experiment(
            project_id, DearDiary.IN_PROGRESS, "Repro Auto Experiment",
        )

        driver_id = DearDiary.with_iteration(experiment_id) do iter
            iter.id
        end
        driver = driver_id |> DearDiary.get_iteration
        # The driver iteration gets the env snapshot — at minimum the Julia version is
        # populated regardless of where Pkg state lives.
        @test driver.julia_version |> !isempty

        # A child run (with_iteration on a parent) should inherit, not re-capture.
        child_id = DearDiary.with_iteration(
            experiment_id; parent_iteration_id=driver_id,
        ) do iter
            iter.id
        end
        child = child_id |> DearDiary.get_iteration
        @test child.julia_version |> isempty

        # Opting in via `snapshot=true` overrides the per-child default.
        opted_in_id = DearDiary.with_iteration(
            experiment_id; parent_iteration_id=driver_id, snapshot=true,
        ) do iter
            iter.id
        end
        opted_in = opted_in_id |> DearDiary.get_iteration
        @test opted_in.julia_version |> !isempty
    end
end

@with_deardiary_test_db begin
    @testset verbose = true "restore materialises the captured environment" begin
        user = DearDiary.get_user("default")
        project_id, _ = DearDiary.create_project(user.id, "Restore Project")
        experiment_id, _ = DearDiary.create_experiment(
            project_id, DearDiary.IN_PROGRESS, "Restore Experiment",
        )
        iteration_id, _ = DearDiary.create_iteration(experiment_id)
        DearDiary.snapshot_environment!(iteration_id; entrypoint="train.jl")

        mktempdir() do depot
            result = DearDiary.restore(iteration_id; depot=depot)

            @test result isa DearDiary.RestoreResult
            @test result.julia_version == (VERSION |> string)
            @test result.entrypoint == "train.jl"

            project_path = joinpath(result.project_path, "Project.toml")
            manifest_path = joinpath(result.project_path, "Manifest.toml")
            @test project_path |> isfile
            @test manifest_path |> isfile

            # Round-trip integrity: the bytes written to disk match the bytes captured.
            iteration = iteration_id |> DearDiary.get_iteration
            @test read(project_path, String) == iteration.project_toml
            @test read(manifest_path, String) == iteration.manifest_toml
        end
    end

    @testset verbose = true "restore rejects missing iteration" begin
        @test_throws ArgumentError DearDiary.restore(9999)
    end

    @testset verbose = true "restore rejects iteration without snapshot" begin
        user = DearDiary.get_user("default")
        project_id, _ = DearDiary.create_project(user.id, "Restore Empty Project")
        experiment_id, _ = DearDiary.create_experiment(
            project_id, DearDiary.IN_PROGRESS, "No Snapshot",
        )
        iteration_id, _ = DearDiary.create_iteration(experiment_id)

        @test_throws ArgumentError DearDiary.restore(iteration_id)
    end
end
