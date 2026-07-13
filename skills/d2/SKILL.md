---
name: d2
description: "Draw diagrams as code from text using the D2 language (d2lang.com). Use when the user wants to create, edit, validate, or render architecture diagrams, flowcharts, sequence diagrams, ER diagrams, class diagrams, or any .d2 file. Triggers: draw a diagram, architecture diagram, visualize the system, render d2, .d2 file."
license: MIT
metadata:
  author: skale
  version: "1.0.0"
---

# D2 — Diagrams as Code

D2 turns text into diagrams. **Knowledge skill** — no scripts; the agent drives the `d2` CLI directly. Requires the `d2` binary: `brew install d2`.

## Install

```bash
openskills install devskale/skale-skills/skills/d2   # → pi, claude, opencode, …
```
Or clone + add to pi config (`~/.pi/agent/settings.json`): `"skills": ["~/code/skale-skills/skills/d2"]`.

## The Render Loop

```bash
d2 validate diagram.d2        # syntax check FIRST
d2 diagram.d2                 # → diagram.svg (self-contained default)
d2 diagram.d2 diagram.txt     # ASCII preview — the agent's only way to self-verify
```

## Core Syntax

```d2
a -> b: label                 # directed edge with label
a <-> b                       # bidirectional
a -- b                        # undirected (no arrow)
# NOTE: chains like `a -> b -> c: label` label EVERY edge — see Gotchas

db: { shape: cylinder; style.multiple: true }
queue: { shape: queue }
user: { shape: person }

worker: {                     # containers + dot notation (nesting)
  redis: { shape: queue }
}
worker -> worker.redis: enqueue

vars: { d2-config: {          # per-file config → reproducible without CLI flags
  layout-engine: elk
  theme-id: 300               # `d2 themes` to list
} }
```

## Gotchas

- **Default layout is `dagre`; prefer `elk` for delivery.** dagre is a Sugiyama-style layoutor built for *directed acyclic* graphs — weak on cycles, bidirectional/undirected edges, and dense fan-in/fan-out (more crossings, poorer spacing as graphs grow). **ELK** (Eclipse Layout Kernel) routes and spaces dense graphs better. Set `layout-engine: elk` in `vars.d2-config`. (`tala` is paid and usually absent.)
- **The ASCII/text export ignores `--layout` and `vars.d2-config.layout-engine`.** Verified: `--layout dagre` vs `elk` (and the `vars` setting) produce **byte-identical `.txt`**. So ASCII self-verification works with any engine, **but it will not reflect the layout of your delivered SVG/PNG** — what you read in `.txt` is the exporter's fixed layout, not your configured one. Verify *structure* in ASCII; trust the SVG by construction.
- **Vertical (default ELK) is agent-verifiable; `direction: right` is not.** A wide horizontal diagram terminal-wraps into noise in ASCII, so you can't self-verify it. Build and verify vertical; switch to horizontal only as a final delivery choice.
- **SVG is the sane default — zero dependencies, self-contained** (`--bundle=true` by default). **PNG/PDF trigger a ~141 MiB Playwright + FFMPEG download** on first run. Deliver SVG unless the user needs raster.
- **No native HTML export.** Formats: svg, png, pdf, pptx, gif, txt. For an HTML deliverable, embed the SVG with `--no-xml-tag` (drops `<?xml?>` so it embeds) and `--salt <name>` (unique IDs when embedding multiple SVGs).
- **Verify before rendering:** `d2 validate x.d2` (syntax) and `d2 fmt x.d2 --check` (lint without writing; `d2 fmt x.d2` formats in place). `fmt --check` is idempotent after `fmt`.
- **Chain edge labels apply to EVERY edge, not the last.** Verified: `a -> b -> c: label` labels both `a→b` and `b→c`. Use separate statements (`a -> b` then `b -> c: label`) for per-edge labels.
- **Label syntax:** keys with spaces need no quotes (`cell tower:` works), but `label:` strings with special chars do. Multi-line labels use `\n`. Use `name: { label: "Displayed Text" }` to decouple the identifier from shown text.
- **Don't reference icons that aren't installed** — `icon: great-icon:apple` hard-fails the compile if the set is missing. Omit icons unless certain.
- **A node that only receives edges gets pushed to the end of the layout.** A shared sink (e.g. an LLM cloud that everything calls but calls nothing) lands at the bottom/right, not "to the side". Don't fight the layout trying to pin it mid-flow.
- **Cross-cutting fan-in tangles the layout.** If many nodes connect to one sink (every step → one LLM cloud), long edges route across the whole graph → noisy ASCII, busy SVG. Mitigations (in order): (a) draw one representative edge + state "all X → sink" in a legend; (b) drop the sink and note it; (c) draw all edges only when the *fan-in itself* is the point.
- **Small retry loops render fine; long write-back cycles do not.** A short `assess → retry → assess` lays out cleanly; a write-back to an early data node (`flow → data.json → flow`) creates a long-distance cycle that tangles. Prefer a distinct downstream node (e.g. `final verdict`) over writing back upstream.

## Output Formats

| Format | Command | Notes |
|---|---|---|
| SVG | `d2 x.d2 x.svg` | Default. Self-contained, web-friendly. |
| PNG | `d2 x.d2 x.png` | Needs Playwright (first-run ~141 MiB download). |
| PDF | `d2 x.d2 x.pdf` | Needs Playwright. Clickable links. |
| ASCII | `d2 x.d2 x.txt` | Any engine (exporter ignores `--layout`). **Use to self-verify structure.** |
| PPTX/GIF | `d2 x.d2 x.pptx` | For multi-board compositions. |

## Workflow: Code → Architecture Diagram

1. Read the codebase: entry points, module boundaries, data stores, external calls, infra.
2. Group components into **containers** (services, layers). Nest with dot notation.
3. Use `shape:` to encode type: `cylinder`/`stored_data` (DBs), `queue`, `person`, `cloud` (external).
4. `d2 validate`, render to `.txt`, **read the ASCII** to confirm structure, then deliver SVG.
5. Deliver the `.d2` source (editable, version-controllable) + `.svg` (viewable).

## Reference

- Full syntax catalog (shapes, styles, special objects, composition): [`references/syntax.md`](references/syntax.md)
- Architecture-pattern cookbook (layered, request-flow, microservices, pub/sub, C4 container, deployment): [`references/recipes.md`](references/recipes.md)
- CLI: `d2 --help`, `d2 layout`, `d2 themes`. Tour: https://d2lang.com/tour/intro/
