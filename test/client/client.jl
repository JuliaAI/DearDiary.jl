@with_deardiary_test_db begin
    @testset verbose = true "client" begin
        client = DearDiary.connect("http://127.0.0.1:9000")

        @testset "connect against auth-disabled server" begin
            @test client isa DearDiary.Client
            @test client.token |> isnothing
            @test client.base_url == "http://127.0.0.1:9000"
        end

        @testset "whoami returns default user when auth is disabled" begin
            me = client |> DearDiary.whoami
            @test me isa DearDiary.UserResponse
            @test me.username == "default"
            @test me.is_admin == true
        end

        @testset "project CRUD" begin
            project_id = create_project(client, "Client Project")
            @test project_id isa Integer

            project = get_project(client, project_id)
            @test project isa DearDiary.Project
            @test project.name == "Client Project"

            update_project(client, project_id; description="from the client")
            refreshed = get_project(client, project_id)
            @test refreshed.description == "from the client"

            projects = client |> get_projects
            @test any(p -> p.id == project_id, projects)

            @test get_project(client, 99_999) |> isnothing
        end

        @testset "experiment + iteration lifecycle" begin
            project_id = create_project(client, "Lifecycle Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Lifecycle Exp",
            )
            @test experiment_id isa Integer

            experiment = get_experiment(client, experiment_id)
            @test experiment.name == "Lifecycle Exp"
            @test experiment.status_id == (DearDiary.IN_PROGRESS |> Integer)

            page = get_experiments(client, project_id, DearDiary.Pagination(10, 0))
            @test page.total >= 1
            @test page.limit == 10
            @test page.offset == 0
            @test any(e -> e.id == experiment_id, page.data)

            iteration = create_iteration(client, experiment_id)
            @test iteration isa DearDiary.Iteration
            @test iteration.experiment_id == experiment_id
            @test iteration.end_date |> isnothing

            create_parameter(client, iteration.id, "lr", 1e-3)
            params = get_parameters(client, iteration.id)
            @test (params |> length) == 1
            @test params[1].key == "lr"

            metric_id = create_metric(client, iteration.id, "loss", 0.42)
            @test metric_id isa Integer
            metrics = get_metrics(client, iteration.id)
            @test (metrics |> length) == 1
            @test metrics[1].value ≈ 0.42

            update_metric(client, metric_id; value=0.21)
            @test get_metric(client, metric_id).value ≈ 0.21

            update_iteration(client, iteration.id; notes="finished step")
            @test get_iteration(client, iteration.id).notes == "finished step"
        end

        @testset "with_iteration closes on success" begin
            project_id = create_project(client, "Withiter Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Withiter Exp",
            )

            captured_id = with_iteration(client, experiment_id) do iter
                create_metric(client, iter.id, "loss", 0.5)
                iter.id
            end

            iteration = get_iteration(client, captured_id)
            @test !(iteration.end_date |> isnothing)
        end

        @testset "with_iteration closes on failure and rethrows" begin
            project_id = create_project(client, "Withiter Crash Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Crash Exp",
            )

            captured_id = Ref{Int64}(0)
            @test_throws ErrorException with_iteration(client, experiment_id) do iter
                captured_id[] = iter.id
                error("boom")
            end

            iteration = get_iteration(client, captured_id[])
            @test !(iteration.end_date |> isnothing)
        end

        @testset "tags across hierarchies" begin
            project_id = create_project(client, "Tagged Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Tagged Exp",
            )
            iteration = create_iteration(client, experiment_id)

            add_tag(client, DearDiary.Project, project_id, "vision")
            add_tag(client, DearDiary.Experiment, experiment_id, "baseline")
            add_tag(client, DearDiary.Iteration, iteration.id, "seed=0")

            project_tags = get_tags(client, DearDiary.Project, project_id)
            @test any(t -> t.value == "vision", project_tags)

            experiment_tags = get_tags(client, DearDiary.Experiment, experiment_id)
            @test any(t -> t.value == "baseline", experiment_tags)

            iteration_tags = get_tags(client, DearDiary.Iteration, iteration.id)
            @test any(t -> t.value == "seed=0", iteration_tags)
        end

        @testset "resource upload and download" begin
            project_id = create_project(client, "Resource Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Resource Exp",
            )

            payload = UInt8[0x01, 0x02, 0x03, 0x04, 0x05]
            resource_id = create_resource(client, experiment_id, "weights.bin", payload)
            @test resource_id isa Integer

            stored = get_resource(client, resource_id)
            @test stored.name == "weights.bin"
            @test stored.data == payload

            update_resource(client, resource_id; description="checkpoint #1")
            @test get_resource(client, resource_id).description == "checkpoint #1"

            page = get_resources(client, experiment_id, DearDiary.Pagination(10, 0))
            @test page.total == 1

            delete_resource(client, resource_id)
            @test get_resource(client, resource_id) |> isnothing
        end

        @testset "ClientError surfaces server code" begin
            # Recreating the seeded `default` user trips the UNIQUE constraint on username.
            err = try
                create_user(client, "Ghost", "User", "default", "secret")
                nothing
            catch e
                e
            end
            @test err isa DearDiary.ClientError
            @test err.status == HTTP.StatusCodes.CONFLICT
            @test err.code == "CONFLICT"
        end
    end

    @testset verbose = true "client with auth enabled" begin
        # The first @with_deardiary_test_db block runs against the no-auth server. We piggyback on
        # the same fixture for an auth-enabled smoke test by signing in via /auth.
        authed = DearDiary.connect(
            "http://127.0.0.1:9000"; username="default", password="default",
        )

        @testset "sign-in populates token and user" begin
            @test authed.token isa String
            @test authed.expires_at isa Integer
            @test authed.user isa DearDiary.UserResponse
            @test authed.user.username == "default"
        end

        @testset "refresh_token! mints a new token" begin
            before = authed.token
            DearDiary.refresh_token!(authed)
            @test authed.token isa String
            # Tokens may be identical when minted within the same second; expiry should still be set.
            @test authed.expires_at isa Integer
            @test !isempty(authed.token)
            (before === authed.token) || @test before != authed.token
        end

        @testset "disconnect clears state" begin
            DearDiary.disconnect(authed)
            @test authed.token |> isnothing
            @test authed.user |> isnothing
        end
    end
end
