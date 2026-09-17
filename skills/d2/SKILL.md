---
name: d2
version: "1.4.1"
description: "Draw diagrams as code from text using the D2 language (d2lang.com). Knowledge skill — drives the `d2` CLI directly, plus a few thin bundled wrappers (`scripts/d2v`, `d2png`, `d2fresh`). Use when the user wants to create, edit, validate, or render architecture diagrams, flowcharts, sequence diagrams, ER diagrams, class diagrams, or any .d2 file. Triggers: draw a diagram, architecture diagram, visualize the system, render d2, .d2 file."
license: MIT
disable-model-invocation: true
---

# D2 — Diagrams as Code

> **Manual only** — invoke explicitly with `/skill:d2`; the agent won't reach for it on its own.

D2 turns text into diagrams. **Knowledge skill** — the agent drives the `d2` CLI directly; `scripts/` only adds thin wrappers. Requires `brew install d2`.

> **Ecosystem:** hand-drawn presentation figures (sketchy look, manual layout) → **`figure`** ·
> shareable page/report (one HTML + URL) → **`visualize`** · `d2` = auto-laid-out technical
> diagrams (sequence, ER, class, many types) with ASCII self-verification.

## Install

```bash
openskills install devskale/skale-skills/skills/d2   # → pi, claude, opencode, …
```
Or clone + add to pi config: `"skills": ["~/code/skale-skills/skills/d2"]` in `~/.pi/agent/settings.json`.

## Quick Start — the render loop

```bash
bash scripts/d2v diagram.d2          # ONE command: validate → ASCII to stderr → svg → width-bloat check
bash scripts/d2v diagram.d2 -- --sketch --theme 4   # forward flags to d2 (sketch/themes — sketch is CLI-only, vars ignore it)
bash scripts/d2png diagram.d2        # PNG via rsvg-convert (no Playwright/Chromium download)
# (the raw loop it runs, if you need the pieces:)
d2 validate diagram.d2               # grammar check
d2 diagram.d2 diagram.txt            # ASCII preview — verify structure (the agent's self-check)
d2 diagram.d2                        # → diagram.svg (self-contained default)
```

**Output dir:** rendered output (`.svg`/`.png`/`.pdf`) → `$XDG_CACHE_HOME/generated/`
(default `~/.cache/generated/`), override with an explicit path for deliverables. Keep
the `.d2` source in the repo (editable, version-controllable) — rendered output is a
build artifact.

## Core Syntax

```d2
a -> b: label                 # directed edge with label
a <-> b                       # bidirectional
a -- b                        # undirected (no arrow)
# NOTE: chains like `a -> b -> c: label` label EVERY edge — see Gotchas

db: { shape: cylinder; style.multiple: true }
queue: { shape: queue }
user: { shape: person }

vars: { d2-config: {          # per-file config → reproducible without CLI flags
  layout-engine: elk
  theme-id: 300               # `d2 themes` to list
} }
```

## Gotchas (top 3 — full list: [references/gotchas.md](references/gotchas.md))

- **Prefer `elk` over the default `dagre`** for delivery — set `layout-engine: elk` in `vars.d2-config`.
- **`d2 validate` is permissive** (grammar only) — unknown shapes/styles only fail at render; verify by rendering to `.txt`.
- **Check the viewBox ratio** (`width/height > ~2.2` = squished) before delivering; side branches and wall-of-text labels blow the width.

## Output Formats

| Format | Command | Notes |
|---|---|---|
| SVG | `d2 x.d2 x.svg` | Default. Self-contained, web-friendly. |
| PNG | `bash scripts/d2png x.d2 x.png` | SVG → `rsvg-convert` (librsvg). No Playwright download. |
| PDF | `d2 x.d2 x.pdf` | Needs Playwright (d2 built-in). |
| ASCII | `d2 x.d2 x.txt` | Any engine (exporter ignores `--layout`). **Use to self-verify structure.** |
| PPTX/GIF | `d2 x.d2 x.pptx` | For multi-board compositions. |

## Render flags

| Flag | Use |
|---|---|
| `--target 'layers.x.*'` | render one board / multi-board (`layers`/`scenarios`/`steps`); `--target=''` = root only |
| `--scale 0.5` | halve / double the output size |

## Workflow: Code → Architecture Diagram

1. Read the codebase: entry points, module boundaries, data stores, external calls, infra.
2. Group components into **containers** (services, layers). Nest with dot notation.
3. Use `shape:` to encode type: `cylinder`/`stored_data` (DBs), `queue`, `person`, `cloud` (external).
4. `d2 validate`, render to `.txt`, **read the ASCII** to confirm structure, then deliver SVG.
5. Deliver the `.d2` source (editable, version-controllable) + `.svg` (viewable).

## References

- [references/gotchas.md](references/gotchas.md) — **verified CLI traps. Read when a render fails or looks wrong.**
- [references/syntax.md](references/syntax.md) — shapes, styles, containers/nesting, composition. **Read when** you need a specific keyword.
- [references/recipes.md](references/recipes.md) — architecture-pattern cookbook (layered, request-flow, microservices, pub/sub, C4, deployment). **Read when** starting a new architecture diagram.
- [references/diagram-types.md](references/diagram-types.md) — sequence, ER/sql_table, class diagrams. **Read when** drawing one of those types.
- [references/delivery.md](references/delivery.md) — delivery polish (links/tooltips, icons, multi-board, themes, sketch). **Read when** finalizing for delivery.
- CLI: `d2 --help`, `d2 layout`, `d2 themes`. Tour: https://d2lang.com/tour/intro/
