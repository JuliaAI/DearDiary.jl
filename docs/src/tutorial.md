# Tutorial
This tutorial will guide you through the core features of this library. By the end of this
tutorial, you will have a solid understanding of how to use the library effectively.
Let's get started!

## Requirements
To run this tutorial, you need to have the following packages installed:
- [MLJ.jl](https://github.com/JuliaAI/MLJ.jl) - A machine learning framework for Julia
- [MLJDecisionTreeInterface.jl](https://github.com/JuliaAI/MLJDecisionTreeInterface.jl) - Decision tree models for MLJ
- [JLSO.jl](https://github.com/invenia/JLSO.jl) - Julia Serialized Object file format
- [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) - For handling tabular data

You can install these packages using Julia's package manager. Open the Julia REPL and run:

```julia
using Pkg
Pkg.add("MLJ")
Pkg.add("MLJDecisionTreeInterface")
Pkg.add("JLSO")
Pkg.add("DataFrames")
```

## Loading the Data
First, we need to load the dataset that we will be using for this tutorial.

```julia
using MLJ
using JLSO
using DataFrames
using DearDiary

iris = DataFrames.DataFrame(load_iris())
train, test = partition(iris, 0.8, shuffle=true)

train_y, train_X = unpack(train, ==(:target))
test_y, test_X = unpack(test, ==(:target))
```

## Initializing the database
Before we start tracking our experiments, we need to initialize the database where the
experiment data will be stored.

```julia-repl
julia> DearDiary.initialize_database()
[ Info: Database initialized successfully.
```

This will create a local SQLite database file named `deardiary.db` in the current
directory.

## Creating a new project and experiment
Projects help you organize your experiments. Let's create a new project for our iris
classification experiment.

```julia-repl
julia> project_id, _ = create_project("Tutorial project")
(1, DearDiary.Created())
```

Once we have a project, we can create an experiment within that project.

```julia-repl
julia> experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "Iris classification experiment")
(1, DearDiary.Created())
```

!!! note
    In the case that something goes wrong during the project or experiment creation, the
    functions will return `nothing` and a marker type indicating the type of error.
    You can check the marker types in the [Miscellaneous](@ref) section of the
    documentation.

## Training the model and tracking the experiment
Now we are ready to train a machine learning model and track the experiment using the
library. We will use a decision tree classifier for this example.

```julia-repl
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

```julia-repl
julia> mach = machine(model, train_X, train_y)
untrained Machine; does not cache data
  model: ProbabilisticTunedModel(model = DecisionTreeClassifier(max_depth = -1, …), …)
  args:
    1:  Source @745 ⏎ Table{AbstractVector{Continuous}}
    2:  Source @879 ⏎ AbstractVector{Multiclass{3}}
```

```julia-repl
julia> fit!(mach)
[ Info: Training machine(ProbabilisticTunedModel(model = DecisionTreeClassifier(max_depth = -1, …), …), …).
[ Info: Attempting to evaluate 9 models.
Evaluating over 9 metamodels: 100%[=========================] Time: 0:00:06
trained Machine; does not cache data
  model: ProbabilisticTunedModel(model = DecisionTreeClassifier(max_depth = -1, …), …)
  args:
    1:  Source @745 ⏎ Table{AbstractVector{Continuous}}
    2:  Source @879 ⏎ AbstractVector{Multiclass{3}}
```

After training the model, we can log the results of the experiment to the database.

```julia
model_values = report(mach).history .|> (x -> (x.measure, x.measurement, x.model.max_depth))

for (measure, measurements, max_depth) in model_values
    iteration_id, _ = create_iteration(experiment_id)
    create_parameter(iteration_id, "max_depth", max_depth)

    measures_names = [split(x |> string, "(") |> first for x in measure]
    for (name, value) in zip(measures_names, measurements)
        create_metric(iteration_id, name, value)
    end
end
```

## Viewing the logged data
You can retrieve and check the logged data from the database to ensure everything was
logged correctly.

```julia-repl
julia> iteration = last(get_iterations(experiment_id)) # Checking only the last iteration
DearDiary.Iteration
 ├ id = 9
 ├ experiment_id = 3
 ├ notes = ""
 ├ created_date = 2025-11-01T18:53:38.409
 └ end_date = nothing
```

```julia-repl
julia> get_parameters(iteration.id)
1-element Vector{DearDiary.Parameter}:
DearDiary.Parameter
 ├ id = 9
 ├ iteration_id = 9
 ├ key = "max_depth"
 └ value = "5"
```

```julia-repl
julia> get_metrics(iteration.id)
4-element Vector{DearDiary.Metric}:
DearDiary.Metric
 ├ id = 33
 ├ iteration_id = 9
 ├ key = "Accuracy"
 └ value = 0.9500000000000001
DearDiary.Metric
 ├ id = 34
 ├ iteration_id = 9
 ├ key = "LogLoss"
 └ value = 1.5109739936187825
DearDiary.Metric
 ├ id = 35
 ├ iteration_id = 9
 ├ key = "MisclassificationRate"
 └ value = 0.05000000000000001
DearDiary.Metric
 ├ id = 36
 ├ iteration_id = 9
 ├ key = "BrierScore"
 └ value = -0.09074074074074075
```

## Save and load the trained model
You can save serialized objects, files, or any other resources related to your experiments.

```julia
smach = serializable(mach)
io = IOBuffer()
JLSO.save(io, :machine => smach)

bytes = take!(io)
```

```julia-repl
julia> resource_id, _ = create_resource(experiment_id, "Iris DTC MLJ Machine", bytes)
(1, DearDiary.Created())
```

Then you can load the model back when needed.

```julia-repl
julia> resource = get_resource(resource_id)
 DearDiary.Resource
 ├ id = 1
 ├ experiment_id = 3
 ├ name = "Iris DTC MLJ Machine"
 ├ description = ""
 ├ data = UInt8[0x87, 0x7a, 0x00, …, 0x36, 0x34, 0x62]
 ├ created_date = 2025-11-01T18:56:50.165
 └ updated_date = nothing
```

```julia
io = IOBuffer(resource.data)
loaded_mach = JLSO.load(io)[:machine]
```

```julia-repl
julia> restore!(loaded_mach)
trained Machine; does not cache data
  model: ProbabilisticTunedModel(model = DecisionTreeClassifier(max_depth = -1, …), …)
  args:
```

## Built-in REST API
The library also provides a built-in REST API to allow the outside world to interact with
your projects. You can start the API server using the following command:

```julia
DearDiary.run(;)
```

This will start the API server on `http://localhost:9000`. You can customize the settings
by setting an `.env` file containing the configuration options. For more details, refer to
the [REST API](@ref) section of the documentation.

## Conclusion
And that's it! You have successfully completed the tutorial and learned how to use the
core features of this library. You can now track your machine learning experiments
effectively. For more advanced features and options, refer to the rest of the
documentation.
