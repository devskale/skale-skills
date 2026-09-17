---
name: figure
version: "1.2.1"
description: "Hand-drawn 'Daily Dose of DS'-style architecture / pipeline / workflow figures from a small spec — sketchy Excalidraw-style nodes, pastel fills, dashed arrows, numbered step badges, semantic colour coding. Bundles a Node compositor that assembles CC0 icons + the Patrick Hand font into matching SVG + PNG. Same spec → identical figure every time. Use when the user wants to draw, create, or render an architecture diagram, pipeline figure, workflow diagram, or any .fig.mjs. Triggers: draw a diagram, architecture figure, pipeline figure, render a figure, .fig.mjs, make a diagram."
metadata:
  author: skale-dev
disable-model-invocation: true
---

# figure — hand-drawn architecture figures from a spec

> **Manual only** — invoke explicitly with `/skill:figure`; the agent won't reach for it
> on its own.

Write a small spec (nodes + edges + badges) → a consistent hand-drawn SVG **and** PNG,
assembled from CC0 icons + the Patrick Hand font. Same spec → identical figure every
time; a palette change in the library re-styles every figure on rebuild.

> **Ecosystem:** auto-laid-out technical diagrams (sequence/ER/class, many nodes) → the
> **`d2`** skill · shareable page/report (cards, timelines, one HTML + URL) → the
> **`visualize`** skill · `figure` = hand-drawn, durable presentation figures where you
> place every node yourself.

> **Provenance:** vendored from the [`figure/` toolchain](https://github.com/skale-dev/rag-eval/tree/main/figure)
> in skale-dev/rag-eval (commit `d9fd6424`, 2026-07-28). Compositor, icons, font, house
> style are CC0/OFL — see `LICENSING.md`; third-party reference images were **not**
> copied (`styleguide/reference/NOTICE.md`).

## Quick start

```bash
cd skills/figure
node build/build_figures.mjs diagrams/my-fig.fig.mjs   # -> ~/.cache/generated/<name>/{*.svg,*.png}
node build/build_figures.mjs                           # build every *.fig.mjs under diagrams/
```

- **Output:** `$XDG_CACHE_HOME/generated` (default `~/.cache/generated/`); override with `FIGURE_OUT_DIR`.
- **Needs:** Node ≥18. PNG uses `rsvg-convert` (`brew install librsvg`) — no
  Playwright/Chromium; if missing, the build emits SVG and skips PNG with a warning.
- **Always-on lint:** every build prints geometry checks to stderr — out-of-bounds
  nodes/labels, text collisions, node overlaps (warnings, non-blocking) and a hard
  exit 1 when an edge's `from`/`to` isn't a declared node. Standalone:
  `node build/review_figure.mjs diagrams/x.fig.mjs`.

## Authoring

Each figure gets a folder under a topic group in `diagrams/` (e.g.
`diagrams/architectures/rewoo-agent/`) containing `<name>.fig.mjs`, a default-exported
spec. Coordinates are absolute; `(x,y)` is a node's top-left; author on a loose grid.
Full node/edge field reference: `build/README.md`. Worked example:
`diagrams/architectures/rewoo-agent/rewoo-agent.fig.mjs`.

```js
export default {
  name: 'my-figure', title: 'My Pipeline', width: 1200, height: 760,
  nodes: [
    { id: 'q',   x: 60,  y: 110, icon: 'doc-envelope',      color: 'tan',   label: 'Query' },
    { id: 'agt', x: 300, y: 110, icon: 'llm-agent-brain',   agent: true,    label: 'Decide' },
    { id: 'out', x: 540, y: 110, icon: 'doc-lines-success', color: 'green', label: 'Answer' },
  ],
  edges: [
    { from: 'q',   to: 'agt', badge: 1 },
    { from: 'agt', to: 'out', badge: 2, branch: 'yes' },
  ],
};
```

## House style (short version)

- **Golden rule:** every diagram is a *hand-drawn sketch*, not a corporate flowchart.
- **One font everywhere:** Patrick Hand (OFL) — font stacks end in `cursive`, never `sans-serif`.
- **Dashed arrows** are the default connector; thin dark-grey stroke, simple arrowhead.
- **Numbered step badges** (cream `#FDF0D0`, dashed orange border) on every transition,
  in execution order — the compositor snaps them to clear whitespace.
- **Semantic colour** (agent = red, LLM = amber, success = green, web = blue …):
  palette table in `styleguide/STYLE.md` §7.

Full style: `styleguide/STYLE.md` · licensing policy (non-negotiable, no vendor logos,
no CC-BY): `LICENSING.md`.

## Layout

| Path | What |
|------|------|
| `build/` | compositor — `compose.mjs` (library), `raster.mjs` (SVG→PNG), `build_figures.mjs` (CLI); see `build/README.md` |
| `assets/` | CC0 icons, images, house font — **reuse before redrawing**; see `assets/README.md` |
| `styleguide/` | house style (`STYLE.md`) + reference NOTICE |
| `diagrams/` | specs + built output — kept examples: `architectures/` (react/rewoo/traditional RAG), `scope/` |
| `_scratch/` | **gitignored** local one-off figures — don't commit |

## Install

Ships in the `skale-skills` pi package: `pi install git:github.com/devskale/skale-skills`,
then enable `figure` via `pi config`. Standalone symlink:
`ln -s "$(pwd)/skills/figure" ~/.pi/agent/skills/figure`.
