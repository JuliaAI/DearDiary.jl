const _DOCS_URL = "https://juliaai.github.io/DearDiary.jl/dev/"

"""
    _iteration_status(status_id::Integer)::NamedTuple

Map an [`IterationStatus`](@ref) id to the badge tone and label the dashboard renders.
Unknown ids fall back to a neutral tone so a corrupted row never breaks a page.
"""
function _iteration_status(status_id::Integer)
    status_id == Integer(RUNNING) && return (tone="slate", label="running")
    status_id == Integer(SUCCEEDED) && return (tone="sage", label="succeeded")
    status_id == Integer(FAILED) && return (tone="brick", label="failed")
    status_id == Integer(KILLED) && return (tone="plum", label="killed")
    return (tone="neutral", label="unknown")
end

function _experiment_status(status_id::Integer)
    status_id == Integer(IN_PROGRESS) && return (tone="slate", label="in progress")
    status_id == Integer(STOPPED) && return (tone="plum", label="stopped")
    status_id == Integer(FINISHED) && return (tone="sage", label="finished")
    return (tone="neutral", label="unknown")
end

function _stage(stage_id::Integer)
    stage_id == Integer(NO_STAGE) && return (tone="neutral", label="no stage")
    stage_id == Integer(STAGING) && return (tone="ochre", label="staging")
    stage_id == Integer(PRODUCTION) && return (tone="sage", label="production")
    stage_id == Integer(ARCHIVED) && return (tone="plum", label="archived")
    return (tone="neutral", label="unknown")
end

# Coarse human-readable duration: milliseconds below a second, then the largest one or two
# units so a quick scan reads "1.06s" / "2m 3s" / "1h 12m".
function _format_duration(d::Millisecond)::String
    ms = d.value
    ms < 0 && return "–"
    ms < 1000 && return "$(ms) ms"
    s = ms / 1000
    s < 60 && return "$(round(s; digits=2))s"
    if s < 3600
        m, rem = divrem(round(Int, s), 60)
        return "$(m)m $(rem)s"
    end
    h, rem = divrem(round(Int, s), 3600)
    return "$(h)h $(rem ÷ 60)m"
end

function _relative_time(dt::DateTime, ref::DateTime=now())::String
    delta_s = max(0, (ref - dt).value / 1000)
    delta_s < 60 && return "just now"
    delta_s < 3600 && return "$(round(Int, delta_s / 60))m ago"
    delta_s < 86400 && return "$(round(Int, delta_s / 3600))h ago"
    delta_s < 7 * 86400 && return "$(round(Int, delta_s / 86400))d ago"
    Dates.year(dt) == Dates.year(ref) && return Dates.format(dt, "u d")
    return Dates.format(dt, "u d, yyyy")
end

_format_datetime(dt::DateTime)::String = Dates.format(dt, "u d, yyyy HH:MM")
_format_datetime(::Nothing)::String = "–"
_format_date(dt::DateTime)::String = Dates.format(dt, "u d, yyyy")

# Metric values are shown with four significant digits. Whole numbers drop the decimal
# point, and magnitudes outside the comfortable range fall back to Julia's exponent form.
function _format_number(v::Real)::String
    isnan(v) && return "NaN"
    isinf(v) && return (v > 0 ? "Inf" : "-Inf")
    v == 0 && return "0"
    rounded = round(float(v); sigdigits=4)
    (abs(rounded) >= 1e6 || abs(rounded) < 1e-4) && return string(rounded)
    rounded == round(rounded) && return string(Int(rounded))
    return string(rounded)
end

function _format_bytes(n::Integer)::String
    n < 1024 && return "$(n) B"
    units = ("KB", "MB", "GB", "TB")
    value = n / 1024
    idx = 1
    while value >= 1024 && idx < length(units)
        value /= 1024
        idx += 1
    end
    text = value >= 100 ? string(round(Int, value)) : string(round(value; digits=1))
    return "$(text) $(units[idx])"
end

_short_sha(sha::AbstractString)::String = length(sha) > 7 ? String(sha[1:7]) : String(sha)

function _pluralize(
    n::Integer, singular::AbstractString, plural::AbstractString="$(singular)s"
)
    return "$(n) $(n == 1 ? singular : plural)"
end

function _truncate(s::AbstractString, limit::Integer)::String
    length(s) <= limit && return String(s)
    return String(first(s, max(limit - 1, 1))) * "…"
end

_line_count(s::AbstractString)::Int =
    isempty(s) ? 0 : count(==('\n'), s) + (endswith(s, '\n') ? 0 : 1)

function _display_name(user::User)::String
    full = strip("$(user.first_name) $(user.last_name)")
    return isempty(full) ? user.username : full
end

function _initials(user::User)::String
    parts = filter(!isempty, [user.first_name, user.last_name])
    isempty(parts) && return uppercase(String(first(user.username, 1)))
    return uppercase(join(String(first(p, 1)) for p in parts))
end

_project_url(id::AbstractString)::String = "/project/$(id)"
_experiment_url(id::AbstractString)::String = "/experiment/$(id)"
_iteration_url(id::AbstractString)::String = "/iteration/$(id)"
_model_url(id::AbstractString)::String = "/model/$(id)"
_download_url(id::AbstractString)::String = "/resource/$(id)/download"
