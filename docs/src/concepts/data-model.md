# Data model

DearDiary organises tracking data as a four-level hierarchy. Understanding the hierarchy
makes it easier to choose where to attach a given piece of information.

## Entity hierarchy

```
Project
└── Experiment
    ├── Resource
    └── Iteration
        ├── Parameter
        └── Metric
```

A [`Project`](@ref DearDiary.Project) is the top-level container. Each project owns one or more
[`Experiment`](@ref DearDiary.Experiment)s, and each experiment owns one or more [`Iteration`](@ref DearDiary.Iteration)s.
Parameters and metrics are scoped to a single iteration; artifact resources attach to the
parent experiment.

Tags attach at three levels: a [`Tag`](@ref DearDiary.Tag) can be associated with a project, an
experiment, or an iteration via the [`add_tag`](@ref) function.

## Iterations

An [`Iteration`](@ref DearDiary.Iteration) represents one training run or evaluation job. It carries a lifecycle
status ([`IterationStatus`](@ref DearDiary.IterationStatus)): `RUNNING` when the run is in progress, then one of
`SUCCEEDED`, `FAILED`, or `KILLED` when it ends. On failure, the iteration row stores the
captured exception text in `error_message`.

Iterations form parent/child trees through `parent_iteration_id`. A child iteration whose
`parent_iteration_id` is set points at the parent run that spawned it. This models common
multi-run patterns:

- hyperparameter optimisation trials under a driver sweep
- nested cross-validation folds
- distributed-worker fan-outs

[`get_child_iterations`](@ref) returns the direct children of a given iteration.

## Metrics

A [`Metric`](@ref DearDiary.Metric) is a named floating-point measurement. Repeated logs of the same key
form a series indexed by `step`, so a training script can record a loss curve across epochs
in a single iteration.

## Resources

A [`Resource`](@ref DearDiary.Resource) stores artifact bytes (model checkpoints, plots, data files) attached
to an experiment. The backend that holds the bytes is recorded on the row itself (see
[Storage](@ref) for details).

## Model registry

The model registry adds two more entity types, both project-scoped:

- [`Model`](@ref DearDiary.Model): a named entry in the registry. Unique by name within its project.
- [`ModelVersion`](@ref DearDiary.ModelVersion): one concrete checkpoint of a model. Each version has a monotonically
  increasing version number, points at the [`Iteration`](@ref DearDiary.Iteration) that produced it, and
  optionally links to a [`Resource`](@ref DearDiary.Resource) holding the serialised bytes.

A freshly registered version starts at stage [`NO_STAGE`](@ref DearDiary.NO_STAGE). It can be promoted to
[`STAGING`](@ref DearDiary.STAGING), then [`PRODUCTION`](@ref DearDiary.PRODUCTION). Promoting a version to production automatically
archives the previous incumbent. Superseded versions move to [`ARCHIVED`](@ref DearDiary.ARCHIVED).
