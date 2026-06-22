---
name: d2
description: "Draw diagrams as code from text using the D2 language (d2lang.com). Use when the user wants to create, edit, validate, or render architecture diagrams, flowcharts, sequence diagrams, ER diagrams, class diagrams, or any .d2 file. Triggers: draw a diagram, architecture diagram, visualize the system, render d2, .d2 file."
license: MIT
metadata:
  author: skale
  version: "0.0.1"
---

# D2 — Diagrams as Code

> **v0.0.1 — WIP.** Gotchas are failure-backed. Missing: sequence/ER guides,
> composition recipes, tests, a .d2 library. Resume: read **`WORKLOG.md`**.

D2 turns text into diagrams. Knowledge skill — no scripts.

## Install

```bash
openskills install devskale/skale-skills/skills/d2   # GitHub → pi, claude, opencode, …
```
Or clone + add to pi config (`~/.pi/agent/settings.json`): `"skills": ["~/code/skale-skills/skills/d2"]`. Requires `d2`: `brew install d2`.

## The Render Loop

```bash
d2 validate diagram.d2        # check syntax first
d2 diagram.d2                 # → diagram.svg (default, self-contained)
d2 diagram.d2 diagram.txt     # ASCII preview — SEE GOTCHAS, critical for agents
```

## Core Syntax

```d2
# nodes + edges
a -> b: label                 # directed edge with label
a <-> b                       # bidirectional
a -- b                        # undirected (no arrow)
# NOTE: chains like `a -> b -> c: label` label EVERY edge — see Gotchas

# shapes + styles
db: { shape: cylinder; style.multiple: true }
queue: { shape: queue }
user: { shape: person }
logs: { shape: page; style.multiple: true }

# containers + dot notation (nesting)
worker: {
  robotni
  redis: { shape: queue }
}
worker.robotni -> worker.redis: enqueue

# per-file config (reproducible without CLI flags)
vars: {
  d2-config: {
    layout-engine: elk
    theme-id: 300              # Terminal theme. Run `d2 themes` to list all.
  }
}
```

## Gotchas

- **ELK is mandatory for agent workflows, not optional.** As an agent you cannot view rendered SVG/PNG. The only way to self-verify a diagram is `d2 x.d2 x.txt` (ASCII), and **ASCII export only works with `elk` or `tala`** — it silently falls back and renders nothing useful with `dagre`. Always set `layout-engine: elk` in `vars.d2-config`.
- **Default layout is `dagre`.** Mediocre past a few nodes. Use `elk` (bundled, free) for most diagrams. `tala` is paid and usually not installed.
- **SVG is the sane default — zero dependencies, self-contained** (`--bundle=true` by default). **PNG/PDF trigger a ~141 MiB Playwright + FFMPEG download on first run** on a fresh machine. Deliver SVG unless the user needs raster.
- **No native HTML export.** Formats: svg, png, pdf, pptx, gif, txt. For an HTML deliverable, embed the SVG with `--no-xml-tag` (drops `<?xml?>` so it embeds cleanly) and `--salt <name>` (unique IDs when embedding multiple SVGs on one page).
- **Verify before rendering:** `d2 validate x.d2` (syntax) and `d2 fmt x.d2` (format in place; `--check` to lint without writing).
- **Label syntax:** names with spaces need no quotes in keys (`cell tower:` works), but `label:` strings with special chars do. Multi-line labels use `\n`. Use `name: { label: "Displayed Text" }` to decouple the identifier from shown text.
- **Don't reference icons that aren't installed** — `icon: great-icon:apple` hard-fails the compile if the icon set is missing. Omit icons unless certain.
- **Vertical (default ELK) is the agent-verifiable layout; `direction: right` is not.** ASCII export of a wide horizontal diagram terminal-wraps into noise, so you cannot self-verify a `direction: right` diagram. Build and verify vertical; only switch to horizontal as a final delivery choice you trust by structure, not by sight.
- **Chain edge labels apply to EVERY edge in the chain, not the last.** `a -> b -> c: label` labels both `a→b` and `b→c`. Use separate statements (`a -> b` then `b -> c: label`) for per-edge labels.
- **A node that only receives edges gets pushed to the end of the layout.** A shared service like an LLM cloud that tasks *call* (but which calls nothing) lands at the bottom/right of the diagram, not "to the side". Acceptable, but expect it; don't fight the layout trying to pin it mid-flow.
- **Cross-cutting shared-resource edges tangle the layout.** If many nodes connect to one sink (e.g. every step → one LLM cloud), ELK must route long edges across the whole graph, producing noisy ASCII and busy SVGs. Mitigations, in order of preference: (a) draw one representative edge and state "all X steps → sink" in a comment/legend; (b) drop the sink node entirely and note it; (c) only draw all edges when the *fan-in itself* is the point of the diagram.
- **Small retry nodes render fine; large write-back cycles do not.** A self-correcting loop `assess → retry → assess` (small node, short hop) lays out cleanly in ELK. A write-back to an early data node (`auditflow → projekt.json → auditflow`) creates a long-distance cycle that tangles. Prefer a distinct downstream node (e.g. `final verdict`) over writing back to an upstream artifact.

## Output Formats

| Format | Command | Notes |
|--------|---------|-------|
| SVG | `d2 x.d2 x.svg` | Default. Self-contained, web-friendly. |
| PNG | `d2 x.d2 x.png` | Needs Playwright (first-run download). |
| PDF | `d2 x.d2 x.pdf` | Needs Playwright. Clickable links. |
| ASCII | `d2 x.d2 x.txt` | ELK/TALA only. **Use to self-verify.** |
| PPTX/GIF | `d2 x.d2 x.pptx` | For multi-board compositions. |

## Workflow: Code → Architecture Diagram

1. Read the codebase: entry points, module boundaries, data stores, external calls, infra.
2. Group components into **containers** (services, machines, layers). Use dot notation to nest.
3. Use `shape:` to encode type: `cylinder`/`stored_data` (DBs, stores), `queue`, `person` (users), `cloud` (external).
4. `d2 validate`, then render to `.txt` and **read the ASCII** to confirm structure before delivering the SVG.
5. Deliver the `.d2` source (editable, version-controllable) + `.svg` (viewable).

## Reference

- Full syntax catalog — all shapes, styles, special objects, composition: see `references/syntax.md`
- CLI: `d2 --help`, `d2 layout`, `d2 themes`. Tour: https://d2lang.com/tour/intro/
