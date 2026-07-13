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

## 6. Publishable assets (licensing)

Anything in a diagram that ships publicly — a README, a docs site, a paper — should be usable **without attribution**. (Adapted from the rag-eval `figure/` skill's licensing policy.)

- **Self-made diagrams (your own `.d2`) are always safe** — you own the output. This is the default; lean on it.
- **Icons:** prefer **CC0 / public-domain** (e.g. [SVG Repo](https://www.svgrepo.com) filtered to CC0) or self-drawn. **OFL fonts** embed fine with no attribution.
- **Avoid vendor / product logos** (AWS, OpenAI, Postgres, Redis, …) — they carry trademark + attribution baggage. Use **generic shapes** instead: a `cylinder`/`stored_data` for *any* datastore, `cloud` for *any* external service / LLM / API, `queue` for a bus/cache/topic. D2's shape vocabulary is generic by default — prefer it over branded icons.
- **Avoid CC-BY / CC-BY-SA** (attribution required) and any "free for personal use" asset.
- If you do reuse an external icon, **record its license + source** in a comment next to the node.

## 7. Consistency vocabulary (house style across a project)

For a set of diagrams in one repo or docs site, pin a shared look so they read as one system — same role = same shape + colour in every diagram.

| Role | Shape | Suggested colour |
|---|---|---|
| user / actor | `person` | — |
| your system / container | `rectangle` | theme accent |
| datastore (any DB) | `cylinder` / `stored_data` | tan/grey |
| bus / cache / topic | `queue` | — |
| external service / LLM / API | `cloud` | blue |
| document / artifact | `page` | — |
| success / accept | `document` | green outline |
| reject / failure | `document` | red outline |

- **Pin it once:** put `vars: { d2-config: { layout-engine: elk; theme-id: <id> } }` plus your shape/colour conventions in a **shared header snippet** that every diagram starts from — a theme change there re-styles them all (D2 rebuilds each `.d2` → identical output).
- **Parallel labels:** use the same wording everywhere ("API Gateway" in every diagram, not "Gateway"/"API"/"gw").
- Reuse shapes/icons across diagrams; don't redraw the same role differently.

---

## Putting it together

A README-ready architecture map often combines several: a **light theme** + **clickable links** to each service's doc + **tooltips** for one-line metadata, rendered to **SVG** (self-contained, GitHub-safe):

```bash
d2 --theme 101 --bundle architecture.d2 architecture.svg
```

Verify before shipping: `d2 validate architecture.d2`, then open the SVG (ASCII can't show links/tooltips/columns — those are SVG-only).
