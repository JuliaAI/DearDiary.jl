@with_deardiary_test_db begin
    @testset verbose = true "client" begin
        client = DearDiary.connect("http://127.0.0.1:9000")

        @testset "connect against auth-disabled server" begin
            @test client isa DearDiary.Client
            @test isnothing(client.token)
            @test client.base_url == "http://127.0.0.1:9000"
        end

        @testset "whoami returns default user when auth is disabled" begin
            me = DearDiary.whoami(client)
            @test me isa DearDiary.UserResponse
            @test me.username == "default"
            @test me.is_admin == true
        end

        @testset "project CRUD" begin
            project_id = create_project(client, "Client Project")
            @test project_id isa String
            @test !isempty(project_id)

            project = get_project(client, project_id)
            @test project isa DearDiary.Project
            @test project.name == "Client Project"

            update_project(client, project_id; description="from the client")
            refreshed = get_project(client, project_id)
            @test refreshed.description == "from the client"

            projects = get_projects(client)
            @test any(p -> p.id == project_id, projects)

            @test isnothing(get_project(client, "00000000-0000-0000-0000-000000000000"))
        end

        @testset "experiment + iteration lifecycle" begin
            project_id = create_project(client, "Lifecycle Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Lifecycle Exp"
            )
            @test experiment_id isa String
            @test !isempty(experiment_id)

            experiment = get_experiment(client, experiment_id)
            @test experiment.name == "Lifecycle Exp"
            @test experiment.status_id == (Integer(DearDiary.IN_PROGRESS))

            page = get_experiments(client, project_id, DearDiary.Pagination(10, 0))
            @test page.total >= 1
            @test page.limit == 10
            @test page.offset == 0
            @test any(e -> e.id == experiment_id, page.data)

            iteration = create_iteration(client, experiment_id)
            @test iteration isa DearDiary.Iteration
            @test iteration.experiment_id == experiment_id
            @test isnothing(iteration.end_date)

            create_parameter(client, iteration.id, "lr", 1e-3)
            params = get_parameters(client, iteration.id)
            @test (length(params)) == 1
            @test params[1].key == "lr"

            metric_id = create_metric(client, iteration.id, "loss", 0.42)
            @test metric_id isa String
            @test !isempty(metric_id)
            metrics = get_metrics(client, iteration.id)
            @test (length(metrics)) == 1
            @test metrics[1].value ≈ 0.42

            update_metric(client, metric_id; value=0.21)
            @test get_metric(client, metric_id).value ≈ 0.21

            update_iteration(client, iteration.id; notes="finished step")
            @test get_iteration(client, iteration.id).notes == "finished step"
        end

        @testset "with_iteration closes on success" begin
            project_id = create_project(client, "Withiter Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Withiter Exp"
            )

            captured_id = with_iteration(client, experiment_id) do iter
                create_metric(client, iter.id, "loss", 0.5)
                iter.id
            end

            iteration = get_iteration(client, captured_id)
            @test !(isnothing(iteration.end_date))
        end

        @testset "with_iteration closes on failure and rethrows" begin
            project_id = create_project(client, "Withiter Crash Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Crash Exp"
            )

            captured_id = Ref{String}("")
            @test_throws ErrorException with_iteration(client, experiment_id) do iter
                captured_id[] = iter.id
                error("boom")
            end

            iteration = get_iteration(client, captured_id[])
            @test !(isnothing(iteration.end_date))
        end

        @testset "tags across hierarchies" begin
            project_id = create_project(client, "Tagged Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Tagged Exp"
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
                client, project_id, DearDiary.IN_PROGRESS, "Resource Exp"
            )

            payload = UInt8[0x01, 0x02, 0x03, 0x04, 0x05]
            resource_id = create_resource(client, experiment_id, "weights.bin", payload)
            @test resource_id isa String
            @test !isempty(resource_id)

            stored = get_resource(client, resource_id)
            @test stored.name == "weights.bin"
            # As of v0.7.0 metadata responses no longer carry bytes; fetch them separately.
            @test isnothing(stored.data)
            @test stored.size_bytes == (length(payload))
            @test read_resource_data(client, resource_id) == payload

            update_resource(client, resource_id; description="checkpoint #1")
            @test get_resource(client, resource_id).description == "checkpoint #1"

            page = get_resources(client, experiment_id, DearDiary.Pagination(10, 0))
            @test page.total == 1

            delete_resource(client, resource_id)
            @test isnothing(get_resource(client, resource_id))
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

        @testset "user CRUD" begin
            user_id = create_user(client, "Alice", "Doe", "alice-client", "s3cret!")
            @test user_id isa String
            @test !isempty(user_id)

            user = get_user(client, user_id)
            @test user isa DearDiary.UserResponse
            @test user.username == "alice-client"
            @test user.first_name == "Alice"
            @test user.is_admin == false

            update_user(client, user_id; first_name="Alicia", is_admin=true)
            @test get_user(client, user_id).first_name == "Alicia"
            @test get_user(client, user_id).is_admin == true

            users = get_users(client)
            @test users isa Array{DearDiary.UserResponse,1}
            @test any(u -> u.id == user_id, users)
            @test all(u -> !hasfield(typeof(u), :password), users)

            delete_user(client, user_id)
            @test isnothing(get_user(client, user_id))
        end

        @testset "userpermission CRUD" begin
            user_id = create_user(client, "Bob", "Roe", "bob-client", "hunter2")
            project_id = create_project(client, "Permissioned Project")

            # New project: only the creator (default admin) has a UserPermission row.
            initial = get_userpermissions(client, DearDiary.Project, project_id)
            @test initial isa Array{DearDiary.UserPermission,1}
            @test any(p -> p.read_permission, initial)

            permission_id = create_userpermission(
                client, user_id, project_id, true, true, false, false
            )
            @test permission_id isa String
            @test !isempty(permission_id)

            fetched = get_userpermission(client, user_id, project_id)
            @test fetched isa DearDiary.UserPermission
            @test fetched.create_permission == true
            @test fetched.read_permission == true
            @test fetched.update_permission == false
            @test fetched.delete_permission == false

            update_userpermission(
                client, permission_id; update_permission=true, delete_permission=true
            )
            after = get_userpermission(client, user_id, project_id)
            @test after.update_permission == true
            @test after.delete_permission == true

            by_user = get_userpermissions(client, DearDiary.User, user_id)
            @test any(p -> p.project_id == project_id, by_user)

            by_project = get_userpermissions(client, DearDiary.Project, project_id)
            @test any(p -> p.user_id == user_id, by_project)

            delete_userpermission(client, permission_id)
            @test isnothing(get_userpermission(client, user_id, project_id))

            delete_user(client, user_id)
            delete_project(client, project_id)
        end

        @testset "experiment update + delete" begin
            project_id = create_project(client, "ExpMutation Project")
            experiment_id = create_experiment(
                client, project_id, (Integer(DearDiary.IN_PROGRESS)), "Mutating Exp"
            )

            # `update_experiment` requires `status_id` on every call. The
            # ExperimentStatus-typed positional overload passes it without changing it.
            update_experiment(
                client,
                experiment_id,
                DearDiary.IN_PROGRESS;
                name="Renamed",
                description="updated description",
            )
            renamed = get_experiment(client, experiment_id)
            @test renamed.name == "Renamed"
            @test renamed.description == "updated description"

            # Terminate the experiment.
            update_experiment(client, experiment_id, DearDiary.STOPPED; end_date=now())
            stopped = get_experiment(client, experiment_id)
            @test stopped.status_id == (Integer(DearDiary.STOPPED))
            @test !(isnothing(stopped.end_date))

            # Reopen via the keyword form: status_id back to IN_PROGRESS clears end_date.
            update_experiment(
                client, experiment_id; status_id=(Integer(DearDiary.IN_PROGRESS))
            )
            reopened = get_experiment(client, experiment_id)
            @test reopened.status_id == (Integer(DearDiary.IN_PROGRESS))
            @test isnothing(reopened.end_date)

            # Unpaged convenience listing.
            listing = get_experiments(client, project_id)
            @test listing isa Array{DearDiary.Experiment,1}
            @test any(e -> e.id == experiment_id, listing)

            delete_experiment(client, experiment_id)
            @test isnothing(get_experiment(client, experiment_id))
        end

        @testset "iteration listing and delete" begin
            project_id = create_project(client, "IterListing Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Listing Exp"
            )

            iter1 = create_iteration(client, experiment_id)
            iter2 = create_iteration(client, experiment_id)

            unpaged = get_iterations(client, experiment_id)
            @test unpaged isa Array{DearDiary.Iteration,1}
            @test (length(unpaged)) == 2

            paged = get_iterations(client, experiment_id, DearDiary.Pagination(1, 0))
            @test paged.total == 2
            @test paged.limit == 1
            @test (length(paged.data)) == 1

            delete_iteration(client, iter1.id)
            @test isnothing(get_iteration(client, iter1.id))
            @test get_iteration(client, iter2.id) isa DearDiary.Iteration
        end

        @testset "parameter overloads + CRUD" begin
            project_id = create_project(client, "ParamCRUD Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "ParamCRUD Exp"
            )
            iteration = create_iteration(client, experiment_id)

            string_id = create_parameter(client, iteration.id, "optimizer", "adam")
            real_id = create_parameter(client, iteration.id, "lr", 1e-3)
            @test string_id isa String
            @test !isempty(string_id)
            @test real_id isa String
            @test !isempty(real_id)

            single = get_parameter(client, real_id)
            @test single isa DearDiary.Parameter
            @test single.key == "lr"
            @test single.value == (string(1e-3))

            paged = get_parameters(client, iteration.id, DearDiary.Pagination(1, 1))
            @test paged.total == 2
            @test paged.limit == 1
            @test paged.offset == 1
            @test (length(paged.data)) == 1

            update_parameter(client, string_id; value="sgd")
            @test get_parameter(client, string_id).value == "sgd"

            update_parameter(client, real_id, 5e-4)
            @test get_parameter(client, real_id).value == (string(5e-4))

            delete_parameter(client, string_id)
            @test isnothing(get_parameter(client, string_id))
        end

        @testset "metric paged + delete" begin
            project_id = create_project(client, "MetricCRUD Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "MetricCRUD Exp"
            )
            iteration = create_iteration(client, experiment_id)

            id_a = create_metric(client, iteration.id, "loss", 0.9)
            id_b = create_metric(client, iteration.id, "accuracy", 0.7)

            paged = get_metrics(client, iteration.id, DearDiary.Pagination(1, 0))
            @test paged.total == 2
            @test paged.limit == 1

            delete_metric(client, id_a)
            @test isnothing(get_metric(client, id_a))
            @test get_metric(client, id_b) isa DearDiary.Metric
        end

        @testset "tag get-by-id and delete" begin
            project_id = create_project(client, "TagCRUD Project")
            association_id = add_tag(client, DearDiary.Project, project_id, "client-tag")
            @test association_id isa String
            @test !isempty(association_id)

            tags = get_tags(client, DearDiary.Project, project_id)
            tag = tags[findfirst(t -> t.value == "client-tag", tags)]

            fetched = get_tag(client, tag.id)
            @test fetched isa DearDiary.Tag
            @test fetched.value == "client-tag"

            # Deleting a tag with live parent associations fails on the FK constraint.
            # The REST API has no detach-tag-from-parent endpoint, so a tag created via
            # `add_tag` is undeletable from the client. Verify the failure is reported.
            err = try
                delete_tag(client, tag.id)
                nothing
            catch e
                e
            end
            @test err isa DearDiary.ClientError
            @test err.status == HTTP.StatusCodes.INTERNAL_SERVER_ERROR
            @test err.code == "SERVER_ERROR"
        end

        @testset "resource file overload + name+data update + unpaged listing" begin
            project_id = create_project(client, "FileResource Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "FileResource Exp"
            )

            file_path = tempname() * ".bin"
            payload = UInt8[0x10, 0x20, 0x30]
            try
                write(file_path, payload)
                resource_id = create_resource(client, experiment_id, file_path)
                @test resource_id isa String
                @test !isempty(resource_id)

                stored = get_resource(client, resource_id)
                @test stored.name == basename(file_path)
                @test read_resource_data(client, resource_id) == payload
            finally
                isfile(file_path) && rm(file_path)
            end

            unpaged = get_resources(client, experiment_id)
            @test unpaged isa Array{DearDiary.Resource,1}
            @test (length(unpaged)) == 1

            # Update both metadata and bytes in one call.
            new_payload = UInt8[0xAA, 0xBB, 0xCC, 0xDD]
            update_resource(client, unpaged[1].id; name="renamed.bin", data=new_payload)
            after = get_resource(client, unpaged[1].id)
            @test after.name == "renamed.bin"
            @test read_resource_data(client, unpaged[1].id) == new_payload
        end

        @testset "delete_project cascades" begin
            project_id = create_project(client, "Cascade Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Cascade Exp"
            )
            iteration = create_iteration(client, experiment_id)
            create_parameter(client, iteration.id, "lr", 1e-3)
            create_metric(client, iteration.id, "loss", 0.1)

            delete_project(client, project_id)
            @test isnothing(get_project(client, project_id))
            @test isnothing(get_experiment(client, experiment_id))
            @test isnothing(get_iteration(client, iteration.id))
        end

        @testset "metric step + recorded_at + log_metrics" begin
            project_id = create_project(client, "Step Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Step Experiment"
            )
            iteration = create_iteration(client, experiment_id)

            # Auto step assignment: three log calls for the same key produce 0,1,2.
            create_metric(client, iteration.id, "loss", 0.5)
            create_metric(client, iteration.id, "loss", 0.4)
            create_metric(client, iteration.id, "loss", 0.3)

            losses = [m for m in get_metrics(client, iteration.id) if m.key == "loss"]
            @test [m.step for m in losses] == [0, 1, 2]
            @test [m.value for m in losses] == [0.5, 0.4, 0.3]
            @test all(m -> m.recorded_at isa DateTime, losses)

            # Explicit step + recorded_at round-trip.
            explicit_ts = DateTime(2025, 9, 1, 7, 30, 0)
            create_metric(
                client, iteration.id, "explicit", 1.5; step=100, recorded_at=explicit_ts
            )
            explicit = [m for m in get_metrics(client, iteration.id) if m.key == "explicit"]
            @test (length(explicit)) == 1
            @test explicit[1].step == 100
            @test explicit[1].recorded_at == explicit_ts

            # Batch endpoint.
            ids = log_metrics(
                client, iteration.id, Dict("acc" => 0.94, "val_acc" => 0.89); step=7
            )
            @test ids isa Array{String,1}
            @test (length(ids)) == 2
            batched = [get_metric(client, id) for id in ids]
            @test all(m -> m.step == 7, batched)

            # Batch without step auto-assigns per key.
            log_metrics(client, iteration.id, Dict("rolling" => 0.1))
            log_metrics(client, iteration.id, Dict("rolling" => 0.2))
            rolling = [m for m in get_metrics(client, iteration.id) if m.key == "rolling"]
            @test [m.step for m in rolling] == [0, 1]
        end

        @testset "ClientError on locked iteration" begin
            project_id = create_project(client, "Locked Project")
            experiment_id = create_experiment(
                client, project_id, DearDiary.IN_PROGRESS, "Locked Exp"
            )
            iteration = create_iteration(client, experiment_id)
            update_iteration(client, iteration.id; end_date=now())

            err = try
                create_metric(client, iteration.id, "loss", 0.5)
                nothing
            catch e
                e
            end
            @test err isa DearDiary.ClientError
            @test err.code == "INVALID_PAYLOAD"
        end
    end

    @testset verbose = true "client with auth enabled" begin
        # The first @with_deardiary_test_db block runs against the no-auth server.
        # Reuse the same fixture for an auth-enabled smoke test by signing in via /auth.
        authed = DearDiary.connect(
            "http://127.0.0.1:9000"; username="default", password="default"
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
            @test isnothing(authed.token)
            @test isnothing(authed.user)
        end

        @testset "connect with preset token reuses existing session" begin
            envelope = DearDiary.connect(
                "http://127.0.0.1:9000"; username="default", password="default"
            )
            token = envelope.token

            attached = DearDiary.connect("http://127.0.0.1:9000"; token=token)
            @test attached.token == token
            @test isnothing(attached.user)  # populated lazily via whoami

            me = DearDiary.whoami(attached)
            @test me isa DearDiary.UserResponse
            @test me.username == "default"
            @test attached.user isa DearDiary.UserResponse
        end
    end
end
