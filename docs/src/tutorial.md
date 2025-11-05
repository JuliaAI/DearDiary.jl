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
First, we need to load the dataset that we will be using for this tutorial.

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
Before we start tracking our experiments, we need to initialize the database where the
experiment data will be stored.

```@repl tutorial
DearDiary.initialize_database()
```

This will create a local SQLite database file named `deardiary.db` in the current
directory.

## Creating a new project and experiment
Projects help you organize your experiments. Let's create a new project for our iris
classification experiment.

```@repl tutorial
project_id, _ = create_project("Tutorial project")
```

Once we have a project, we can create an experiment within that project.

```@repl tutorial
experiment_id, _ = create_experiment(project_id, DearDiary.IN_PROGRESS, "Iris classification experiment")
```

!!! note
    In the case that something goes wrong during the project or experiment creation, the
    functions will return `nothing` and a marker type indicating the type of error.
    You can check the marker types in the [Miscellaneous](@ref) section of the
    documentation.

## Training the model and tracking the experiment
Now we are ready to train a machine learning model and track the experiment using the
library. We will use a decision tree classifier for this example.

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

After training the model, we can log the results of the experiment to the database.

```@example tutorial
model_values = report(mach).history .|> (x -> (x.measure, x.measurement, x.model.max_depth))

for (measure, measurements, max_depth) in model_values
    iteration_id, _ = create_iteration(experiment_id)
    create_parameter(iteration_id, "max_depth", max_depth)

    measures_names = [split(x |> string, "(") |> first for x in measure]
    for (name, value) in zip(measures_names, measurements)
        create_metric(iteration_id, name, value)
    end
end
nothing # hide
```

## Viewing the logged data
You can retrieve and check the logged data from the database to ensure everything was
logged correctly.

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
You can save serialized objects, files, or any other resources related to your experiments.

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

Then you can load the model back when needed.

```@repl tutorial
resource = get_resource(resource_id)
```

```@example tutorial
io = IOBuffer(resource.data)
loaded_mach = JLSO.load(io)[:machine]
```

```@repl tutorial
restore!(loaded_mach)
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
