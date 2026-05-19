"""
    @enum Status IN_PROGRESS = 1 STOPPED = 2 FINISHED = 3

An enumeration representing the status of an experiment.
"""
@enum Status IN_PROGRESS = 1 STOPPED = 2 FINISHED = 3

@doc """
    IN_PROGRESS::Status

An enumeration value representing an experiment that is currently in progress.
""" IN_PROGRESS

@doc """
    STOPPED::Status

An enumeration value representing an experiment that has been stopped.
""" STOPPED

@doc """
    FINISHED::Status

An enumeration value representing an experiment that has finished.
""" FINISHED

Base.convert(::Type{Status}, value::Integer) = Status(value)

"""
    @enum Stage NO_STAGE = 1 STAGING = 2 PRODUCTION = 3 ARCHIVED = 4

An enumeration representing the lifecycle stage of a [`ModelVersion`](@ref) in the model
registry. A freshly registered version starts in [`NO_STAGE`](@ref); transitions are driven
by [`update_modelversion`](@ref).
"""
@enum Stage NO_STAGE = 1 STAGING = 2 PRODUCTION = 3 ARCHIVED = 4

@doc """
    NO_STAGE::Stage

An enumeration value representing a [`ModelVersion`](@ref) that has been registered but not
yet promoted to a downstream stage. This is the value assigned at registration time.
""" NO_STAGE

@doc """
    STAGING::Stage

An enumeration value representing a [`ModelVersion`](@ref) that is under review before being
promoted to [`PRODUCTION`](@ref).
""" STAGING

@doc """
    PRODUCTION::Stage

An enumeration value representing a [`ModelVersion`](@ref) that is currently the production
checkpoint for its parent [`Model`](@ref). At most one version per model may hold this stage
at a time; promoting a new version auto-archives the previous incumbent.
""" PRODUCTION

@doc """
    ARCHIVED::Stage

An enumeration value representing a [`ModelVersion`](@ref) that has been superseded and
should not be used for new deployments.
""" ARCHIVED

Base.convert(::Type{Stage}, value::Integer) = Stage(value)
