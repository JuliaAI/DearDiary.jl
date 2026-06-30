"""
    with_iteration(f::Function, client::Client, experiment_id::AbstractString; parent_iteration_id=nothing, snapshot=parent_iteration_id |> isnothing)

Open a fresh [`Iteration`](@ref) under `experiment_id`, invoke `f(iteration)`, and finalise
the iteration regardless of whether the body returns normally or throws. On a clean return
the iteration is marked [`SUCCEEDED`](@ref); on an exception it is marked [`FAILED`](@ref)
with the captured exception text in `error_message`, and the exception is rethrown so the
caller still sees it.

By default the helper attaches an [`EnvironmentSnapshot`](@ref) to the new iteration
immediately after creation, but only when it has no parent: driver runs capture the env,
child runs inherit it. Pass `snapshot=true` to force a per-child capture or
`snapshot=false` to skip entirely.

When `parent_iteration_id` is supplied, the new iteration is registered as a child of the
given parent, useful for HPO sweeps and distributed-worker fan-outs.

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
    f::Function,
    client::Client,
    experiment_id::AbstractString;
    parent_iteration_id::Optional{<:AbstractString}=nothing,
    snapshot::Bool=(isnothing(parent_iteration_id)),
)
    iteration = create_iteration(
        client, experiment_id; parent_iteration_id=parent_iteration_id
    )
    if snapshot
        try
            snapshot_environment!(client, iteration.id)
        catch _
            # Snapshot is best-effort; never block the body on a capture failure.
        end
    end
    try
        result = f(iteration)
        update_iteration(client, iteration.id; status=SUCCEEDED, end_date=now())
        return result
    catch err
        try
            update_iteration(
                client,
                iteration.id;
                status=FAILED,
                end_date=now(),
                error_message=sprint(showerror, err),
            )
        catch _
            # The original exception is more useful than a finaliser failure; keep it.
        end
        rethrow(err)
    end
end
