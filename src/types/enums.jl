@enum Status IN_PROGRESS = 1 STOPPED = 2 FINISHED = 3
Base.convert(::Type{Status}, value::Integer) = Status(value)
