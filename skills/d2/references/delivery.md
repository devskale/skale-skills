# D2 Delivery Polish — links, icons, layers, themes, sketch

Features that take a diagram from "correct" to "shipped" — for READMEs, docs sites, and presentations. All verified against d2 0.7.1.

---

## 1. Interactive links & tooltips

Make nodes **clickable** (`link:`) and **hoverable** (`tooltip:`) in the SVG — perfect for architecture maps where each service links to its own doc.

![interactive](delivery/interactive.svg)

```d2
vars: { d2-config: { layout-engine: elk } }
agent: { shape: person; tooltip: "end user" }
api:  { link: https://d2lang.com;         tooltip: "REST API" }
db:   { shape: cylinder; link: https://www.postgresql.org; tooltip: "primary store" }
agent -> api: call
api -> db
```
- `link: <url>` → the node becomes an `<a href>` in the SVG (opens when clicked).
- `tooltip: "text"` → a `<title>` (browser tooltip on hover).
- Verified: the SVG above carries `href` + `<title>` elements.

Source: [`delivery/interactive.d2`](delivery/interactive.d2)

---

## 2. Icons

D2 renders icons inline. **URL/path icons always work; named icon *sets* must be installed first** (the compile hard-fails if a named set is missing).

```d2
# URL icon — works anywhere (d2 fetches + embeds it)
github: { icon: https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png }

# Local file icon — also always works
logo: { icon: ./assets/logo.png }

# Named set — ONLY if the set is installed, else compile error:
# db: { icon: great-icon:apple }
```
- Prefer **URL or local-file icons** for portability (no install step, verified to embed).
- Use named sets only when you've confirmed the set is present (`d2 --help` → icon docs / `--img-theme`).
- Tip: keep icons small/consistent; too many noisy logos hurt a high-level diagram.

---

## 3. Multi-board — layers, scenarios, steps

There is **no `--multi` flag**. D2 splits a large architecture into multiple boards via **`layers:` / `scenarios:` / `steps:`**, then you render one with `--target` or animate across them with `--animate-interval`.

```d2
layers: {
  context: { user: { shape: person }; system: "System"; user -> system }
  detail:  { api; db: { shape: cylinder }; api -> db }
}
```

```bash
d2 --target layers.context diagram.d2 context.svg   # render ONE board (the context layer)
d2 --animate-interval 1500 diagram.d2 animated.svg  # all boards as one auto-transitioning SVG
d2 diagram.d2 all.svg                               # default: root board
```

![layers: context board](delivery/layers-context.svg)

- **layers** = drill-down (high-level → detail). **scenarios** = alternatives. **steps** = a sequence.
- `--target layers.X` renders just board X; `--target layers.X.*` includes its children.
- `--animate-interval <ms>` packages boards into a single SVG that cycles (great for presentations).

Source: [`delivery/layers.d2`](delivery/layers.d2) · rendered boards: [`layers-context.svg`](delivery/layers-context.svg), [`layers-animated.svg`](delivery/layers-animated.svg)

---

## 4. Themes

Pick a theme by ID with `--theme <id>` (or `vars.d2-config.theme-id`), and a separate dark theme with `--dark-theme` (auto-applies when the viewer's browser is dark). List all with `d2 themes`.

| Use | Theme | ID |
|---|---|---|
| README / docs (light) | Neutral Default · Neutral Grey · Orange Creamsicle | `0` · `1` · `101` |
| Dark sites | Dark Mauve (and other `200`s) | `200` |
| Terminal / dense | Terminal · Terminal Grayscale · C4 | `300` · `301` · `303` |

```bash
d2 --theme 101 diagram.d2 out.svg          # Orange Creamsicle (light, README-friendly)
d2 --theme 300 diagram.d2 out.svg          # Terminal
d2 --theme 200 --dark-theme 200 ...        # dark (and used when viewer is dark)
```
- Default is `0`. Run `d2 themes` for the full list.
- Match the medium: light themes for GitHub READMEs, dark/terminal for dark docs, `303` (C4) for C4-model diagrams.

---

## 5. Sketch mode

`--sketch` renders the diagram as if hand-drawn (roughened lines, sketchy fills) — nice for early-stage/wip diagrams and presentations.

```bash
d2 --sketch diagram.d2 out.svg
```
- Output is notably larger (sketch paths are complex); prefer normal rendering for dense/production diagrams, sketch for "draft" feel.
- Rendered example: [`delivery/sketch.svg`](delivery/sketch.svg)

---

## Putting it together

A README-ready architecture map often combines several: a **light theme** + **clickable links** to each service's doc + **tooltips** for one-line metadata, rendered to **SVG** (self-contained, GitHub-safe):

```bash
d2 --theme 101 --bundle architecture.d2 architecture.svg
```

Verify before shipping: `d2 validate architecture.d2`, then open the SVG (ASCII can't show links/tooltips/columns — those are SVG-only).
