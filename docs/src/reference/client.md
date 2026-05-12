# Client

The Julia client speaks to a running DearDiary REST API. Every CRUD verb (`get_project`, `create_iteration`, `create_metric`, …) gains an extra method that dispatches on a [`Client`](@ref) as the first argument; their docstrings live alongside the in-process versions under the per-entity reference pages.

```julia
using DearDiary

client = DearDiary.connect("http://127.0.0.1:9000"; username="default", password="default")

project_id = create_project(client, "Vision baselines")
experiment_id = create_experiment(client, project_id, DearDiary.IN_PROGRESS, "ResNet50")

with_iteration(client, experiment_id) do iter
    create_parameter(client, iter.id, "lr", 1e-3)
    for epoch in 1:10
        create_metric(client, iter.id, "loss", train_loss(epoch))
    end
end
```

## Connection lifecycle
```@docs
DearDiary.connect
DearDiary.disconnect
DearDiary.refresh_token!
DearDiary.whoami
```
