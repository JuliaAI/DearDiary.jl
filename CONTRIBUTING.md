# Contributing to the project 
Nothing far from the usual process:

> 1. Fork the repository
> 2. Create a new branch
> 3. Make your changes
> 4. Write tests and documentation
> 5. Create a pull request

This project welcomes contributions of all kinds, including bug fixes, new features, documentation improvements, and more. If you're unsure about how to contribute or have any questions, feel free to open an issue or reach out to the maintainers.

## Paradigm and architecture
The project follows a fully-functional programming paradigm, with a focus on immutability and exploiting multiple dispatch. The architecture is a n-layered design, including the following layers:

- **Routes layer**: Responsible for defining the API endpoints and handling incoming requests.
- **Services layer**: Contains the business logic and interacts with the repository layer to perform operations.
- **Repositories layer**: Responsible for data access and manipulation, interacting with the database or other data sources.

The goal is to ensure a clear separation of concerns, which makes the codebase maintainable and scalable. Always think about how another developer would understand your code when making changes, and strive to keep the code clean and well-documented.

## AI-assisted contributions
**TL;DR** you should not be replaced by AI tools, but rather use them as a tool to assist you in your work.

This project encourages the use of AI tools to **assist** in the development process. As a contributor of this project, you are bound to the following rules when using AI tools:
- AI tools can be used for code generation, but the generated code must be reviewed and tested by a human before being merged into the main branch.
- Documentation can be generated using AI tools, but it must be reviewed and edited by a human to ensure accuracy and clarity.
- AI tools can be used for code refactoring, but the changes must be reviewed and tested by a human to ensure that they do not introduce bugs or reduce code readability.
- AI tools can be used for code review, but the final decision on whether to accept or reject a pull request must be made by a human.
- AI tools can be used for testing, but the tests must be reviewed and executed by a human to ensure that they are effective and do not introduce false positives or negatives.


## Code style
The project follows the [BlueStyle](https://github.com/JuliaDiff/BlueStyle) guidelines, but with slight modifications.

!!! note
    The following rules are not enforced, so keep in mind that they are just recommendations, not strict requirements.

### Pipeline operators first
Always use the pipe operator (`|>`) when chaining function calls with a single argument. Inside complex expressions, use parentheses to clarify the order of operations and improve readability.

```julia
# Good
result = data |> process |> analyze

# Good
result = (data |> process) ? true : false

# Bad
result = analyze(process(data))
```

### Multiple dispatch
The greatest feature of Julia, which allows us to write flexible and reusable code. Always consider how to leverage multiple dispatch when designing your functions and types. This can help to reduce code duplication and improve the overall structure of the codebase.
```julia
# Good
function process(data::DataType1)
    # process data of type DataType1
end
function process(data::DataType2)
    # process data of type DataType2
end

# Bad
function process(data)
    if isa(data, DataType1)
        # process data of type DataType1
    elseif isa(data, DataType2)
        # process data of type DataType2
    else
        error("Unsupported data type")
    end
end

# Bad
function process_datatype1(data::DataType1)
    # process data of type DataType1
end

function process_datatype2(data::DataType2)
    # process data of type DataType2
end
```

### Typing
Use type annotations for functions and types. This helps to improve code readability and maintainability, and also allows for better performance and error checking.

- For functions, always annotate abstract types for arguments, and concrete types for return types. This allows for maximum flexibility while still providing type safety.
- For types, always annotate the fields with their concrete types. This helps to ensure that the data is structured correctly and can be easily understood by other developers.

```julia
# Good
struct ExampleType
    field1::Int64
    field2::String
end

# Good
function example_function(arg1::Integer, arg2::AbstractString)::Float64
    # function body
end

# Bad
struct ExampleType
    field1
    field2
end

# Bad
function example_function(arg1, arg2)
    # function body
end
```

### Documentation
If something is pointed to be used by the user, it must be documented. If something is pointed to be used internally, it does not need to be documented, but it should be well-named and self-explanatory.

```julia
# For functions
"""
    example_function(arg1::Integer, arg2::AbstractString)::Float64

This function takes an integer and a string as arguments and returns a float.

# Arguments
- `arg1::Integer`: The first argument, which is an integer.
- `arg2::AbstractString`: The second argument, which is a string.

# Returns
- `Float64`: The result of the function, which is a float.
"""
function example_function(arg1::Integer, arg2::AbstractString)::Float64
    return 0.0
end

# For types
"""
    ExampleType

This type represents an example with two fields: `field1` and `field2`.

# Fields
- `field1::Int64`: The first field, which is an integer.
- `field2::String`: The second field, which is a string.
"""
struct ExampleType
    field1::Int64
    field2::String
end
```
