"""
    @enum ExperimentStatus IN_PROGRESS = 1 STOPPED = 2 FINISHED = 3

An enumeration representing the lifecycle status of an [`Experiment`](@ref).
"""
@enum ExperimentStatus IN_PROGRESS = 1 STOPPED = 2 FINISHED = 3

@doc """
    IN_PROGRESS::ExperimentStatus

An enumeration value representing an experiment that is currently in progress.
""" IN_PROGRESS

@doc """
    STOPPED::ExperimentStatus

An enumeration value representing an experiment that has been stopped.
""" STOPPED

@doc """
    FINISHED::ExperimentStatus

An enumeration value representing an experiment that has finished.
""" FINISHED

Base.convert(::Type{ExperimentStatus}, value::Integer) = ExperimentStatus(value)

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

"""
    @enum IterationStatus RUNNING = 1 SUCCEEDED = 2 FAILED = 3 KILLED = 4

An enumeration representing the lifecycle status of an [`Iteration`](@ref). A freshly
created iteration is [`RUNNING`](@ref); the value transitions to a terminal status
([`SUCCEEDED`](@ref), [`FAILED`](@ref), or [`KILLED`](@ref)) when the iteration ends.
"""
@enum IterationStatus RUNNING = 1 SUCCEEDED = 2 FAILED = 3 KILLED = 4

@doc """
    RUNNING::IterationStatus

An enumeration value representing an [`Iteration`](@ref) that is still in progress. This is
the value assigned when the iteration is created.
""" RUNNING

@doc """
    SUCCEEDED::IterationStatus

An enumeration value representing an [`Iteration`](@ref) that ran to completion without
raising an exception.
""" SUCCEEDED

@doc """
    FAILED::IterationStatus

An enumeration value representing an [`Iteration`](@ref) that ended because of an
exception. The captured exception text is stored in `error_message`.
""" FAILED

@doc """
    KILLED::IterationStatus

An enumeration value representing an [`Iteration`](@ref) that was terminated externally
(operator action, timeout, scheduler kill) rather than by a clean return or an exception.
""" KILLED

Base.convert(::Type{IterationStatus}, value::Integer) = IterationStatus(value)
