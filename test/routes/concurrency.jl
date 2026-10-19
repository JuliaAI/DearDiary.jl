# Requests reach the store from several threads at once when Julia runs with more than one,
# and still interleave at every network wait on a single thread. Each check compares the
# records that landed against the requests that were sent.
@with_deardiary_test_db begin
    @testset verbose = true "concurrent requests" begin
        project_id, _ = DearDiary.create_project("Concurrency Project")
        experiment_id, _ = DearDiary.create_experiment(
            project_id, DearDiary.IN_PROGRESS, "Concurrent Experiment"
        )
        workers = 8
        metrics_per_worker = 25

        @testset "overlapping writers and readers" begin
            writers = map(1:workers) do worker
                Threads.@spawn begin
                    statuses = Int[]
                    response = HTTP.post(
                        "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                        status_exception=false,
                    )
                    push!(statuses, response.status)
                    iteration_id = JSON.parse(String(response.body), Dict{String,Any})["iteration_id"]
                    for step in 1:metrics_per_worker
                        payload = JSON.json(
                            Dict("key" => "loss", "value" => worker / step, "step" => step),
                        )
                        response = HTTP.post(
                            "http://127.0.0.1:9000/metric/iteration/$(iteration_id)";
                            body=payload,
                            status_exception=false,
                        )
                        push!(statuses, response.status)
                    end
                    statuses
                end
            end
            readers = map(1:workers) do _
                Threads.@spawn begin
                    statuses = Int[]
                    for _ in 1:metrics_per_worker
                        response = HTTP.get(
                            "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                            status_exception=false,
                        )
                        push!(statuses, response.status)
                    end
                    statuses
                end
            end

            @test all(==(HTTP.StatusCodes.CREATED), reduce(vcat, fetch.(writers)))
            @test all(==(HTTP.StatusCodes.OK), reduce(vcat, fetch.(readers)))
            iterations = DearDiary.get_iterations(experiment_id)
            @test length(iterations) == workers
            @test all(
                length(DearDiary.get_metrics(iteration.id)) == metrics_per_worker for
                iteration in iterations
            )
        end

        @testset "one model name per project under contention" begin
            registrations = [
                Threads.@spawn DearDiary.create_model(project_id, "contended") for
                _ in 1:workers
            ]
            results = fetch.(registrations)
            @test count(result -> result.status === DearDiary.Created, results) == 1
            @test count(result -> result.status === DearDiary.Duplicate, results) ==
                workers - 1
            @test length(DearDiary.get_models(project_id)) == 1
        end

        @testset "one production version per model under contention" begin
            model_id, _ = DearDiary.create_model(project_id, "promoted")
            iteration_id, _ = DearDiary.create_iteration(experiment_id)
            version_ids = [
                DearDiary.create_modelversion(model_id, iteration_id, nothing, "v").id for
                _ in 1:workers
            ]
            promotions = [
                Threads.@spawn DearDiary.update_modelversion(
                    version_id, Integer(DearDiary.PRODUCTION), nothing, nothing
                ) for version_id in version_ids
            ]
            @test all(result -> result === DearDiary.Updated, fetch.(promotions))
            stages = [version.stage_id for version in DearDiary.get_modelversions(model_id)]
            @test count(==(Integer(DearDiary.PRODUCTION)), stages) == 1
            @test count(==(Integer(DearDiary.ARCHIVED)), stages) == workers - 1
        end
    end
end
