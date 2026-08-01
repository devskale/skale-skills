---
name: figure
version: "1.1.0"
description: "Hand-drawn 'Daily Dose of DS'-style architecture / pipeline / workflow figures from a small spec — sketchy Excalidraw-style nodes, pastel fills, dashed arrows, numbered step badges, semantic colour coding. Bundles a Node compositor that assembles CC0 icons + the Patrick Hand font into matching SVG + PNG. Same spec → identical figure every time. Use when the user wants to draw, create, or render an architecture diagram, pipeline figure, workflow diagram, or any .fig.mjs. Triggers: draw a diagram, architecture figure, pipeline figure, render a figure, .fig.mjs, make a diagram."
metadata:
  author: skale-dev
  version: "1.1.0"
---

# figure — hand-drawn architecture figures from a spec

A figure toolchain: write a small spec (nodes + edges + badges), get a consistent
hand-drawn SVG **and** PNG assembled from a CC0 icon set + the Patrick Hand font. Same
spec → identical figure every time; a palette change in the library re-styles every figure
on rebuild.

> For auto-laid-out technical diagrams (sequence, ER, class, many types) use the **`d2`**
> skill; `figure` is for hand-drawn, presentation-quality explainer figures where you place
> every node yourself.

> **Provenance:** this skill is adapted from the `figure/` toolchain in
> [skale-dev/rag-eval](https://github.com/skale-dev/rag-eval/tree/main/figure) (commit
> `d9fd6424`, 2026-07-28). The compositor (`build/`), icons + font (`assets/`), and house
> style (`styleguide/`) are vendored from upstream and released CC0/OFL — see
> `LICENSING.md`. Thesis-specific example diagrams (`diagrams/metrics/`, `diagrams/dataset/`)
> were trimmed on import; `diagrams/architectures/` + `diagrams/scope/` are kept as general
> examples. The upstream `styleguide/reference/*.jpeg` (third-party copyright, Daily Dose of
> DS) were **not** copied — see `styleguide/reference/NOTICE.md`.

## Quick start — the build loop

```bash
cd skills/figure
npm install && npx playwright install chromium    # one-time; needs Playwright

# write a spec, then build it -> .svg + .png land in ~/generated/images/<name>/
node build/build_figures.mjs diagrams/my-fig.fig.mjs
node build/build_figures.mjs                       # build every *.fig.mjs under diagrams/
```

**Self-verification (always-on lint).** Every build prints a geometry lint to **stderr**:
out-of-bounds nodes/labels, text collisions, node-box overlaps, and aspect-ratio bloat
(warnings — non-blocking; the figure still renders), plus a hard error (exit 1) when an
edge's `from`/`to` isn't a declared node. Read it to catch placement mistakes without
opening the image. Lint a spec standalone: `node build/review_figure.mjs diagrams/x.fig.mjs`.

**In a managed sandbox** where Playwright is already global, skip the install and point
Node at the global modules:

```bash
NODE_PATH=/opt/node22/lib/node_modules node build/build_figures.mjs diagrams/my-fig.fig.mjs
```

## Authoring a figure

Each diagram gets its own folder under a topic group in `diagrams/` (e.g.
`diagrams/architectures/rewoo-agent/`). Create `<name>.fig.mjs` with a default-exported
spec. Coordinates are absolute; `(x,y)` is a node's top-left; author on a loose grid. See
`build/README.md` for the full node/edge field reference and
`diagrams/architectures/rewoo-agent/rewoo-agent.fig.mjs` for a worked example.

```js
export default {
  name: 'my-figure',
  title: 'My Pipeline',
  width: 1200, height: 760,
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

## What's in here

| Path | What |
|------|------|
| `build/` | The compositor — `compose.mjs` (library), `raster.mjs` (SVG→PNG), `build_figures.mjs` (CLI). See `build/README.md`. |
| `assets/` | Reusable CC0 icons (`icons/`), images (`images/`), and the house font **Patrick Hand** (`fonts/`, OFL). Reuse before redrawing. See `assets/README.md`. |
| `styleguide/` | The house style — `STYLE.md` (the look: sketchy strokes, palette, badges, semantic colours), `reference/NOTICE.md`. |
| `diagrams/` | Figure specs (`*.fig.mjs`) + built `.svg`/`.png`. Kept examples: `architectures/` (react/rewoo/traditional RAG), `scope/` (scope-map). |
| `LICENSING.md` | **Read this.** Everything published must be usable without attribution (self-made / CC0 / OFL). No vendor logos, no CC-BY. |
| `package.json` | Pins the Playwright dev dependency. |

## House style (the short version)

- **Golden rule:** every diagram is a *hand-drawn sketch*, not a corporate flowchart.
- **One font everywhere:** `Patrick Hand` (OFL) — titles, labels, badges. No sans, ever;
  SVG/CSS font stacks must end in `cursive`, not `sans-serif`.
- **Dashed arrows** are the default connector; thin dark-grey stroke, simple arrowhead.
- **Numbered step badges** (cream fill `#FDF0D0`, dashed orange border) on every
  transition, in execution order. The compositor snaps them to clear whitespace
  automatically.
- **Semantic colour** (agent = red, LLM = amber, success = green, web = blue …) — see the
  table in `styleguide/STYLE.md` §7.

Full style spec: **`styleguide/STYLE.md`**. Licensing policy: **`LICENSING.md`**.

## Install / activate

This is a pi skill in the `skale-skills` package. Install the package once, globally:

```bash
pi install git:github.com/devskale/skale-skills
```

Then enable the `figure` skill via `pi config` (space = toggle). Or symlink it standalone:

```bash
ln -s "$(pwd)/skills/figure" ~/.pi/agent/skills/figure
```

Requires Node ≥18 and Playwright (`npm install` inside the skill dir).
