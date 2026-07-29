# figure/

Thesis figures and everything needed to keep them visually consistent.

- **`styleguide/`** — the house style for architecture/workflow diagrams.
  - `SKILL.md` — the styleguide skill: how to replicate the hand-drawn agentic-RAG look.
  - `reference/` — exemplar diagrams the style is modelled on.
- **`build/`** — the **figure compositor**: write a spec, get a consistent house-style SVG +
  PNG assembled from the icon set. The repeatable way to build full diagrams. See
  `build/README.md`.
- **`diagrams/`** — figure specs (`*.fig.mjs`) and their built `.svg` + `.png` outputs.
  Each diagram gets its own folder under a topic group (e.g.
  `diagrams/architectures/rewoo-agent/`); the builder scans this tree recursively and
  writes each render next to its spec.
- **`assets/`** — reusable icons (`icons/`), images (`images/`), and the house font
  (`fonts/`). Reuse before redrawing; see `assets/README.md`.
- **`LICENSING.md`** — **read this.** Everything we publish must be usable **without
  attribution** (self-made / CC0 / OFL). Vendor logos and the `reference/` exemplars are
  **not** publishable.

Before making a new figure, read `styleguide/SKILL.md` + `LICENSING.md`, and pull icons
from `assets/`.

## Quickstart (build the figures)

```
cd figure
npm install && npx playwright install chromium   # one-time; needs Playwright
npm run build                                    # renders icon PNGs + all diagrams
```

Requirements and the in-sandbox variant are in `build/README.md`. `package.json` pins the
toolchain deps; outputs (`diagrams/*.svg` + `*.png`, icon `*.png`) are committed.
