# Tutorial
This tutorial covers the core features of DearDiary: initializing a database, creating
projects and experiments, logging metrics and parameters, saving artifacts, and querying
logged data.

## Requirements
Install the following packages before running the tutorial:
- [MLJ.jl](https://github.com/JuliaAI/MLJ.jl) - A machine learning framework for Julia
- [MLJDecisionTreeInterface.jl](https://github.com/JuliaAI/MLJDecisionTreeInterface.jl) - Decision tree models for MLJ
- [JLSO.jl](https://github.com/invenia/JLSO.jl) - Julia Serialized Object file format
- [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) - For handling tabular data

From the Julia REPL:

```@setup tutorial
using Pkg
Pkg.add("MLJ")
Pkg.add("MLJDecisionTreeInterface")
Pkg.add("JLSO")
Pkg.add("DataFrames")
Pkg.add("DearDiary")
```
```julia
using Pkg
Pkg.add("MLJ")
Pkg.add("MLJDecisionTreeInterface")
Pkg.add("JLSO")
Pkg.add("DataFrames")
```

## Loading the Data
Load the Iris dataset and split it into training and test sets.

```@example tutorial
using MLJ
using JLSO
using DataFrames
using DearDiary

iris = DataFrames.DataFrame(load_iris())
train, test = partition(iris, 0.8, shuffle=true)

train_y, train_X = unpack(train, ==(:target))
test_y, test_X = unpack(test, ==(:target))
nothing # hide
```

## Initializing the database
Initialize the database before tracking any experiments.

```julia
DearDiary.initialize_database()
```

```@setup tutorial
# Documenter cd-resets between blocks, so `cd(mktempdir())` in a setup block does not
# persist to the @repl/@example blocks below. Override `file_name` instead; that pins
# the DB to a throwaway location regardless of what cwd Documenter restores. Subsequent
# blocks reuse the connection via the global _DEARDIARY_DATABASE, so nothing else creates
# a file in docs/build/.
using DearDiary
DearDiary.initialize_database(; file_name=joinpath(mktempdir(), "deardiary.db"))
```

This creates a local database file named `deardiary.db` in the current directory.

## Creating a new project and experiment
Projects organize experiments. Create one for the Iris classification run.

```@repl tutorial
project_id, _ = create_project("Tutorial project")
```

With a project in hand, create an experiment inside it.

```@repl tutorial
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "Iris classification experiment")
```

!!! note
    In the case that something goes wrong during the project or experiment creation, the
    functions will return `nothing` and a marker type indicating the type of error.
    You can check the marker types in the [Miscellaneous](@ref) section of the
    documentation.

## Training the model and tracking the experiment
Train a decision tree classifier with MLJ's grid-search tuner and track the results.

```@example tutorial
DecisionTreeClassifier = @load DecisionTreeClassifier pkg=DecisionTree
dtc = DecisionTreeClassifier()
max_depth_range = range(dtc, :max_depth, lower=2, upper=10, scale=:linear)

model = TunedModel(
    model=dtc,
    resampling=CV(),
    tuning=Grid(),
    range=max_depth_range,
    measure=[accuracy, log_loss, misclassification_rate, brier_score],
)
```

```@repl tutorial
mach = machine(model, train_X, train_y)
```

```@repl tutorial
fit!(mach)
```

After training, log each trial's results to the database.

```@example tutorial
model_values = report(mach).history .|> (x -> (x.measure, x.measurement, x.model.max_depth))

for (measure, measurements, max_depth) in model_values
    iteration_id, _ = create_iteration(experiment_id)
    create_parameter(iteration_id, "max_depth", max_depth)

    measures_names = [split(x |> string, "(") |> first for x in measure]
    metrics_at_step = Dict(
        name => value for (name, value) in zip(measures_names, measurements)
    )
    log_metrics(iteration_id, metrics_at_step)
end
nothing # hide
```

Each `create_metric` or `log_metrics` call appends to a per-`(iteration, key)` series. The
server auto-assigns `step` (`max(step) + 1`) and `recorded_at` (`now()`) when you don't pass
them, so logging the same key repeatedly forms a chronological time series, exactly what a
training loop produces over epochs:

```julia
for epoch in 1:10
    log_metrics(iteration_id, Dict("loss" => train_loss(epoch), "acc" => accuracy(epoch)))
end
```

## Viewing the logged data
Retrieve the logged data from the database to verify the results.

```@repl tutorial
iteration = last(get_iterations(experiment_id)) # Checking only the last iteration
```

```@repl tutorial
get_parameters(iteration.id)
```

```@repl tutorial
get_metrics(iteration.id)
```

## Save and load the trained model
Attach a serialized model to the experiment as a resource.

```@example tutorial
smach = serializable(mach)
io = IOBuffer()
JLSO.save(io, :machine => smach)

bytes = take!(io)
nothing # hide
```

```@repl tutorial
resource_id, _ = create_resource(experiment_id, "Iris DTC MLJ Machine", bytes)
```

Load it back when needed.

```@repl tutorial
resource = get_resource(resource_id)
```

The metadata response carries only the artifact's metadata. Fetch the raw bytes via
[`read_resource_data`](@ref).

```@example tutorial
io = IOBuffer(read_resource_data(resource_id))
loaded_mach = JLSO.load(io)[:machine]
```

```@repl tutorial
restore!(loaded_mach)
```

## Built-in REST API
DearDiary includes a REST API for remote access. Start the server with:

```julia
DearDiary.run(;)
```

The server binds to `http://localhost:9000` by default. Customize it with an `.env` file. See the [REST API](@ref) section for details.

## Logging from a remote training script
When the training script runs on a different machine, use the bundled Julia client. Every CRUD verb shown above has a [`Client`](@ref)-aware overload, and [`with_iteration`](@ref) auto-finalises an iteration on success or exception.

```julia
using DearDiary

client = DearDiary.connect(
    "http://server.example:9000"; username="alice", password="secret",
)

project_id = create_project(client, "Iris classification")
experiment_id = create_experiment(
    client, project_id, DearDiary.IN_PROGRESS, "Decision tree sweep",
)

with_iteration(client, experiment_id) do iter
    create_parameter(client, iter.id, "max_depth", 4)
    create_metric(client, iter.id, "accuracy", 0.96)
end
```

See the [Client](@ref) reference for the full list of helpers.

## Conclusion
That covers the core workflow. For advanced features, see the dedicated guides linked from the [Tutorial](@ref) overview and the rest of the reference documentation.
