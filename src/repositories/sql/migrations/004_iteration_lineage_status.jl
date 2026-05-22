"""
    MIGRATION_004_ITERATION_LINEAGE_STATUS

Adds run lineage and lifecycle-status tracking to the `iteration` table.

Columns added:

- `parent_iteration_id INTEGER REFERENCES iteration(id) ON DELETE SET NULL` — points at the
  parent iteration when this row is a child (HPO trial, CV fold, distributed worker). When
  the parent is deleted the child's reference is set to NULL rather than cascading the
  delete, so historical lineage is preserved as far as the data allows.
- `status_id INTEGER NOT NULL DEFAULT 1 CHECK (status_id IN (1, 2, 3, 4))` — current
  lifecycle [`IterationStatus`](@ref). Defaults to `RUNNING`.
- `error_message TEXT DEFAULT ''` — captured exception text when `status_id` is `FAILED`.

The backfill statement promotes every pre-existing row that already had an `end_date` from
the default `RUNNING` to `SUCCEEDED`: prior to this migration the only way an iteration
could be terminated was via `update_iteration` setting `end_date`, which is the
`SUCCEEDED` flow.
"""
const MIGRATION_004_ITERATION_LINEAGE_STATUS = Migration(
    4,
    "iteration_lineage_status",
    [
        "ALTER TABLE iteration ADD COLUMN parent_iteration_id INTEGER REFERENCES iteration(id) ON DELETE SET NULL",
        "ALTER TABLE iteration ADD COLUMN status_id INTEGER NOT NULL DEFAULT 1 CHECK (status_id IN (1, 2, 3, 4))",
        "ALTER TABLE iteration ADD COLUMN error_message TEXT DEFAULT ''",
        "UPDATE iteration SET status_id = 2 WHERE end_date <> ''",
    ],
)
