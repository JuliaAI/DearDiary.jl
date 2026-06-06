# Embedded UI

!!! warning "Experimental"
    The embedded web dashboard is experimental. Its DOM structure, URL paths,
    CSS class names, and the env vars listed below can all change without a
    deprecation cycle. Treat it as a local browsing convenience; do not build
    production tooling on top of its HTML or hard-code its routes into
    automation.

DearDiary boots a small in-process web dashboard alongside the REST API. The
dashboard lets you browse projects, experiments, and iterations recorded by
the default user, inspect parameters and metric charts for any iteration, and
follow parent/child trial trees from a single page.

## Configuration

The UI starts by default. Three env vars control it:

```text
DEARDIARY_ENABLE_UI=true        # set to false to skip booting the UI server
DEARDIARY_UI_HOST=127.0.0.1     # bind address
DEARDIARY_UI_PORT=9001          # port the dashboard listens on
```

A single `DearDiary.run(; env_file=".env")` call boots the REST API and the
dashboard on their respective ports. `DearDiary.stop()` closes both servers
together.

## What you see

- **Sidebar:** A tree of projects to experiments to iterations. Child
  trials nest under their driver iteration so lineage stays visible at a
  glance. Each iteration label carries a status glyph (`✓` succeeded,
  `▶` running, `✗` failed, `⊘` killed), a per-experiment ordinal, and a
  relative timestamp. Example: `✓ Iteration 3 · 12m ago`. The link colour
  (yellow running, red failed, purple killed, default succeeded) reinforces
  the same signal. Ordinals are local to each experiment, so deleting a
  row renumbers the remaining iterations in the sidebar. The canonical
  database id appears in the detail pane header and the browser tab title
  for anyone who needs it.
- **Detail pane:** A status badge, the experiment name, the
  created/ended timestamps, the parent-iteration link when present, the
  parameter table, and an inline-SVG chart of every metric series keyed by
  step. Hovering a point reveals a tooltip with the metric name, step, and
  value. The chart renders server-side; no external JS bundle is fetched.
- **Browser tab title:** The title tracks the selected iteration as
  `#42 · ExperimentName · DearDiary`. The landing page renders as plain
  `DearDiary`.
- **Docs link:** A small `Docs ↗` anchor at the bottom of the sidebar
  opens this documentation site in a new tab.

## Disabling the UI

Set `DEARDIARY_ENABLE_UI=false` in the env file. The REST API on
`DEARDIARY_PORT` continues to run unchanged. Pick this for a headless CI
runner or a container image that needs no browser-facing surface.

## Known limitations

- **Single user.** The dashboard reads as the seeded `default` user. No
  login screen, no multi-tenant view.
- **Read-only.** Mutate state through the REST API or the Julia client; the
  UI exposes no edit affordances.
- **WebSocket-driven title updates.** The browser tab title updates from
  the server via the live WebSocket. Slow connections may show stale title
  text for a second or two after a click.
- **Cold-start latency.** The first request after `DearDiary.run` takes a
  few seconds while Bonito boots its renderer; every subsequent request
  serves in tens of milliseconds. A `PrecompileTools` workload absorbs part
  of this cost into `Pkg.precompile`.
