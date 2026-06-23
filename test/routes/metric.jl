@with_deardiary_test_db begin
    @testset verbose = true "metric routes" begin
        @testset verbose = true "create metric" begin
            project_payload = JSON.json(Dict("name" => "Metric Project"))
            project_response = HTTP.post(
                "http://127.0.0.1:9000/project";
                body=project_payload,
                status_exception=false,
            )
            project_data = JSON.parse(String(project_response.body), Dict{String,Any})
            project_id = project_data["project_id"]

            experiment_payload = JSON.json(Dict(
                "status_id" => (Integer(DearDiary.IN_PROGRESS)),
                "name" => "Experiment for Metrics",
            ))
            experiment_response = HTTP.post(
                "http://127.0.0.1:9000/experiment/project/$(project_id)";
                body=experiment_payload,
                status_exception=false,
            )
            experiment_data = JSON.parse(
                String(experiment_response.body), Dict{String,Any}
            )
            experiment_id = experiment_data["experiment_id"]

            iteration_response = HTTP.post(
                "http://127.0.0.1:9000/iteration/experiment/$(experiment_id)";
                status_exception=false,
            )
            iteration_data = JSON.parse(String(iteration_response.body), Dict{String,Any})
            iteration_id = iteration_data["iteration_id"]

            payload = JSON.json(Dict("key" => "accuracy", "value" => 0.92))
            response = HTTP.post(
                "http://127.0.0.1:9000/metric/iteration/$(iteration_id)";
                body=payload,
                status_exception=false,
            )

            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["metric_id"] == 1
        end

        @testset verbose = true "get metric by id" begin
            response = HTTP.get("http://127.0.0.1:9000/metric/1"; status_exception=false)

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            metric = DearDiary.Metric(data)

            @test metric.id isa Int
            @test metric.iteration_id == 1
            @test metric.key == "accuracy"
            @test metric.value == 0.92
        end

        @testset verbose = true "get metrics" begin
            payload = JSON.json(Dict("key" => "loss", "value" => 0.15))
            HTTP.post(
                "http://127.0.0.1:9000/metric/iteration/1";
                body=payload,
                status_exception=false,
            )

            response = HTTP.get(
                "http://127.0.0.1:9000/metric/iteration/1"; status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["total"] == 2
            @test data["limit"] == 50
            @test data["offset"] == 0
            metrics = DearDiary.Metric.(data["data"])

            @test metrics isa Array{DearDiary.Metric,1}
            @test (length(metrics)) == 2
        end

        @testset verbose = true "update metric" begin
            payload = JSON.json(Dict("key" => "loss", "value" => 0.10))
            response = HTTP.patch(
                "http://127.0.0.1:9000/metric/2"; body=payload, status_exception=false
            )

            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "UPDATED"

            response = HTTP.get("http://127.0.0.1:9000/metric/2"; status_exception=false)
            data = JSON.parse(String(response.body), Dict{String,Any})
            metric = DearDiary.Metric(data)

            @test metric.key == "loss"
            @test metric.value == 0.10
        end

        @testset verbose = true "delete metric" begin
            response = HTTP.delete("http://127.0.0.1:9000/metric/2"; status_exception=false)
            @test response.status == HTTP.StatusCodes.OK
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["message"] == "OK"
        end

        @testset verbose = true "create metric persists step and recorded_at" begin
            # Iteration 1 already exists from earlier in this testset.
            payload = JSON.json(Dict(
                "key" => "f1",
                "value" => 0.81,
                "step" => 9,
                "recorded_at" => "2025-03-04T18:30:00",
            ))
            response = HTTP.post(
                "http://127.0.0.1:9000/metric/iteration/1";
                body=payload,
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.CREATED
            metric_id = JSON.parse(String(response.body), Dict{String,Any})["metric_id"]

            response = HTTP.get(
                "http://127.0.0.1:9000/metric/$(metric_id)"; status_exception=false
            )
            metric = DearDiary.Metric(JSON.parse(String(response.body), Dict{String,Any}))
            @test metric.step == 9
            @test metric.recorded_at == DateTime(2025, 3, 4, 18, 30, 0)
        end

        @testset verbose = true "batch endpoint records multiple metrics" begin
            payload = JSON.json(Dict(
                "step" => 12,
                "recorded_at" => "2025-03-04T18:31:00",
                "metrics" => [
                    Dict("key" => "loss", "value" => 0.27),
                    Dict("key" => "val_loss", "value" => 0.31),
                    Dict("key" => "accuracy", "value" => 0.93),
                ],
            ))
            response = HTTP.post(
                "http://127.0.0.1:9000/metric/iteration/1/batch";
                body=payload,
                status_exception=false,
            )
            @test response.status == HTTP.StatusCodes.CREATED
            data = JSON.parse(String(response.body), Dict{String,Any})
            @test data["metric_ids"] isa AbstractArray
            @test (length(data["metric_ids"])) == 3

            fetched = [
                (r -> DearDiary.Metric(JSON.parse(String(r.body), Dict{String,Any})))(HTTP.get(
                    "http://127.0.0.1:9000/metric/$(id)"; status_exception=false
                )) for id in data["metric_ids"]
            ]
            @test all(m -> m.step == 12, fetched)
            @test all(m -> m.recorded_at == DateTime(2025, 3, 4, 18, 31, 0), fetched)
        end
    end
end
