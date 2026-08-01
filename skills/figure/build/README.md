# build/ — the figure compositor

Assemble full diagrams from the CC0 icon set **repeatably and consistently**. You write a
small spec (nodes + edges + badges); the compositor lays it out with the house palette,
Patrick Hand font, standard boxes, dashed arrows, and numbered step badges — then renders a
matching SVG **and** PNG. Same spec → identical figure, every time.

## Files

- `compose.mjs` — the library. `composeSVG(spec)` → house-style SVG string. Owns the
  palette, fonts, boxes, arrows, badges, title swipe, frame.
- `raster.mjs` — shared SVG→PNG renderer (Playwright + embedded Patrick Hand).
- `build_figures.mjs` — CLI. Builds `figure/diagrams/*.fig.mjs` → `<name>.svg` + `<name>.png`.

## Build

The toolchain needs [Playwright](https://playwright.dev) (declared in `figure/package.json`).

**On your own machine / a fresh clone** — install once, then use the npm scripts:

```
cd figure
npm install            # installs playwright
npx playwright install chromium
npm run figures        # build all diagrams -> diagrams/*.svg + *.png
npm run icons          # re-render assets/**/*.svg -> matching *.png
npm run build          # both
```

**In this managed sandbox** — Playwright is already present globally and Chromium is
pre-installed, so skip the install and point Node at the global modules:

```
NODE_PATH=/opt/node22/lib/node_modules node figure/build/build_figures.mjs          # all specs
NODE_PATH=/opt/node22/lib/node_modules node figure/build/build_figures.mjs figure/diagrams/agentic-rag.fig.mjs
```

Rendered images (`.svg` + `.png`) are written to `~/generated/images/<name>/`
(override with the `FIGURE_OUT_DIR` env var) — **not** next to the spec — so this skill's
`diagrams/` stays clean. Commit the spec; the renders are regenerated. The builder scans
`figure/diagrams/` **recursively**, so specs in subfolders build automatically.

## Authoring a figure

**Each diagram gets its own folder** under a topic group in `diagrams/` (e.g.
`diagrams/architectures/rewoo-agent/`), never loose in `diagrams/` — the spec lives there,
and any variants of the same diagram share that folder. (Rendered images go to
`~/generated/images/<name>/`, not here — see the build section.) Create
`figure/diagrams/<topic>/<diagram>/<name>.fig.mjs` with a default-exported spec.
Coordinates are absolute; `(x,y)` is a node's top-left; author on a loose grid. See
`../diagrams/architectures/rewoo-agent/rewoo-agent.fig.mjs` for a worked example.

```js
export default {
  name: 'my-figure',
  title: 'My Pipeline',
  width: 1200, height: 760,
  nodes: [
    { id: 'q',   x: 60,  y: 110, icon: 'doc-envelope',    color: 'tan',   label: 'Query' },
    { id: 'agt', x: 300, y: 110, icon: 'llm-agent-brain', agent: true,    label: 'Decide' },
    { id: 'out', x: 540, y: 110, icon: 'doc-lines-success', color: 'green', label: 'Answer' },
  ],
  edges: [
    { from: 'q',   to: 'agt', badge: 1 },
    { from: 'agt', to: 'out', badge: 2, branch: 'yes' },
  ],
};
```

### Node fields

| field | meaning |
|-------|---------|
| `id` | unique handle used by edges |
| `x, y` | top-left position (absolute) |
| `w, h` | size (default 150×150) |
| `icon` | icon basename from `../assets/icons/` (e.g. `llm-brain`) |
| `label` | text under the icon (`\n` for line breaks) |
| `color` | semantic stroke colour: `red amber green lilac blue tan maroon` (or a hex) |
| `fill` | override the soft background fill |
| `agent` | `true` → white box + ink border (the "LLM Agent" convention) |
| `plain` | `true` → draw icon/label with no box |
| `iconSize`, `labelSize` | fine-tuning |

### Edge fields

| field | meaning |
|-------|---------|
| `from, to` | node ids |
| `fromSide, toSide` | anchor sides `top/right/bottom/left`; omit for auto |
| `path` | explicit polyline `[[x,y],…]` for L-shaped routes (overrides auto) |
| `dashed` | default `true`; set `false` for a solid arrow |
| `badge` | step number in the cream/orange-dashed badge |
| `badgeT` / `badgeAt` | override badge position: fraction along the path, or absolute `[x,y]` |
| `label` | edge label; `labelT` / `labelAt` / `labelOffset` override its position |
| `branch` | `'yes'` (green) or `'no'` (red); `branchT` / `branchAt` / `branchOffset` override |

**You normally don't set any of the `*T` / `*At` / `*Offset` overrides.** By default the
compositor:
- snaps each **badge** to the nearest clear whitespace on its path, so it never lands on a
  box, another badge, or off the visible span (fixes badges getting clipped/cut off);
- offsets each **edge label** *perpendicular* to the line with a paper halo behind it, so it
  clears the badge and stays readable (fixes hidden/overlapping text);
- draws **all badges and labels on top of the nodes**, so nothing can hide them.

Author only the routing (`path`, `fromSide`/`toSide`); reach for the overrides just to
fine-tune a specific label. In the example, the only override is one `labelT` to pull a
"Prompt" onto the final drop into the LLM.

## Design notes

- **Icons are embedded, not linked** — the output SVG is self-contained (nested `<svg>`),
  so it renders anywhere and needs no sidecar files.
- **Consistency comes from the library**, not the spec: palette, font, badge/arrow/box
  styling live in `compose.mjs`. Change them there and every figure updates on rebuild.
- **No sans, ever** — all text is Patrick Hand with a `cursive` fallback (see
  `../styleguide/SKILL.md` §3).
- Everything the compositor draws is self-made/CC0; keep it that way (`../LICENSING.md`).
- Prefer this route for pipeline/architecture diagrams that must stay consistent across the
  thesis. For one-off freehand sketches, Excalidraw in the same style is still fine.
