# Metric
[`Metric`](@ref DearDiary.Metric) records a single value in a per-`(iteration, key)` series.
Pass `step` and `recorded_at` to position the value in time, or let the server default both:
`step` becomes `max(step) + 1` for that series and `recorded_at` becomes the server clock.

```@docs
get_metric
get_metrics
create_metric
log_metrics
update_metric
delete_metric
```
