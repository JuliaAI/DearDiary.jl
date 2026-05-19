# Model registry

[`DearDiary.Model`](@ref) and [`DearDiary.ModelVersion`](@ref) form a project-scoped
registry on top of the run-tracking entities. A `Model` is the named bucket that downstream
serving code refers to (e.g. `"fraud-classifier"`); a `ModelVersion` is a concrete
checkpoint with lineage back to the [`Iteration`](@ref) that produced it, an optional
pointer at the artifact bytes in any configured storage backend, and a lifecycle
[`DearDiary.Stage`](@ref).

Versions transition through `NO_STAGE → STAGING → PRODUCTION → ARCHIVED`. Promoting a
version to `PRODUCTION` automatically demotes whichever sibling was previously in
`PRODUCTION`, preserving the "at most one production version per model" invariant.

```@setup mr
using DearDiary
DearDiary.initialize_database(; file_name=joinpath(mktempdir(), "deardiary.db"))
```

## Scaffold a project and an iteration

```@repl mr
user = DearDiary.get_user("default");
project_id, _ = create_project(user.id, "Fraud detection");
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "DT sweep");
iteration_id, _ = create_iteration(experiment_id);
create_parameter(iteration_id, "max_depth", 7);
create_metric(iteration_id, "accuracy", 0.96);
```

Save the trained model bytes as a [`Resource`](@ref). Any serialisation format works — the
registry only cares about the byte payload and its lineage.

```@repl mr
checkpoint_bytes = rand(UInt8, 1024);
resource_id, _ = create_resource(experiment_id, "fraud-clf.jlso", checkpoint_bytes);
```

## Register the model

A `Model` is a named entry — the human-readable handle that survives across hundreds of
training runs.

```@repl mr
model_id, _ = create_model(project_id, "fraud-classifier");
```

```@repl mr
get_model(model_id)
```

## Register a version

A `ModelVersion` ties a [`Resource`](@ref) to the [`Iteration`](@ref) that produced it.
The per-model version number is assigned by the server (gap-free, monotonic, unique within
the model):

```@repl mr
version_a_id, _ = create_modelversion(
    model_id, iteration_id, resource_id,
    "Decision tree, max_depth=7",
);
```

```@repl mr
version_a = get_modelversion(version_a_id)
```

A freshly registered version starts in [`DearDiary.NO_STAGE`](@ref). Promote it through the
lifecycle as the model proves itself in evaluation:

```@repl mr
update_modelversion(version_a_id, DearDiary.STAGING, nothing, nothing);
```

```@repl mr
update_modelversion(version_a_id, DearDiary.PRODUCTION, nothing, nothing);
```

## Roll forward to a new checkpoint

Train another iteration, register a second version, and promote it to `PRODUCTION`. The
previous incumbent is auto-archived in the same transaction:

```@repl mr
iteration_b_id, _ = create_iteration(experiment_id);
create_parameter(iteration_b_id, "max_depth", 9);
create_metric(iteration_b_id, "accuracy", 0.974);
resource_b_id, _ = create_resource(experiment_id, "fraud-clf-v2.jlso", rand(UInt8, 1024));

version_b_id, _ = create_modelversion(
    model_id, iteration_b_id, resource_b_id,
    "Decision tree, max_depth=9",
);
update_modelversion(version_b_id, DearDiary.PRODUCTION, nothing, nothing);
```

The previous production version is now archived:

```@repl mr
get_modelversion(version_a_id).stage_id == (DearDiary.ARCHIVED |> Integer)
```

```@repl mr
get_modelversion(version_b_id).stage_id == (DearDiary.PRODUCTION |> Integer)
```

## Browsing the registry

[`get_modelversions`](@ref) returns the per-model history ordered by `version` ascending,
so finding the current production checkpoint is a single filter:

```@repl mr
versions = get_modelversions(model_id);
production = filter(v -> v.stage_id == (DearDiary.PRODUCTION |> Integer), versions);
production[1].version
```

The full lineage is reachable from `version.iteration_id` and `version.resource_id`:

```@repl mr
producing_iteration = (version_b_id |> get_modelversion).iteration_id |> get_iteration
```

```@repl mr
get_parameters(producing_iteration.id)
```

```@setup mr
DearDiary.close_database()
```
