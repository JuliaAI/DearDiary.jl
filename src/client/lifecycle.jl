"""
    with_iteration(f::Function, client::Client, experiment_id::Integer)

Open a fresh [`Iteration`](@ref) under `experiment_id`, invoke `f(iteration)`, and finalise the
iteration by writing `end_date` regardless of whether the body returns normally or throws.

The body's return value is returned to the caller on success. Exceptions thrown by `f` are
rethrown after the iteration is closed, so a training script that crashes mid-run still leaves
a terminated iteration on the server.

# Example
```julia
client = DearDiary.connect("http://127.0.0.1:9000"; username="default", password="default")
result = with_iteration(client, experiment_id) do iter
    create_parameter(client, iter.id, "lr", 1e-3)
    for epoch in 1:10
        create_metric(client, iter.id, "loss", train_step!(model))
    end
    model
end
```
"""
function with_iteration(
    f::Function, client::Client, experiment_id::Integer,
)
    iteration = create_iteration(client, experiment_id)
    try
        result = f(iteration)
        update_iteration(client, iteration.id; end_date=now())
        return result
    catch err
        try
            update_iteration(client, iteration.id; end_date=now())
        catch _
            # The original exception is more useful than a finaliser failure; keep it.
        end
        rethrow(err)
    end
end
