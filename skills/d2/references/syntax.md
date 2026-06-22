# D2 Syntax Reference

Loaded on demand. Full catalog of shapes, styles, special objects, and composition.
All examples below have been validated against `d2` 0.7.1 with `layout-engine: elk`.

## Table of Contents

- [Connections](#connections)
- [Shapes](#shapes)
- [Containers and Dot Notation](#containers-and-dot-notation)
- [Styles](#styles)
- [Special Objects](#special-objects)
- [Composition (layers / scenarios / steps)](#composition)
- [Layouts and Themes](#layouts-and-themes)

## Connections

```d2
a -> b                        # directed
a <- b                        # reverse direction
a <-> b                       # bidirectional
a -- b                        # undirected (line, no arrow)
a -> b: label                 # edge with label
a -> b: { style.stroke: red } # styled edge (block form)
parent.child_a -> parent.child_b   # connect nested nodes
a -> b -> c                   # chains
```

Edge labels can carry their own style block:

```d2
a -> b: fast path { style.animated: true; style.stroke: blue }
```

## Shapes

Set via `shape:`. Common ones for architecture diagrams:

| Shape | Use for |
|-------|---------|
| `rectangle` (default) | generic component / service |
| `cylinder` | database |
| `stored_data` | file store / object store |
| `queue` | message queue, job queue |
| `person` | end user |
| `cloud` | external/managed service |
| `hexagon` | gateway, API |
| `page` | document, log file |
| `oval` | start/end states |
| `step` | pipeline stage |

Add `style.multiple: true` to indicate a stack/multiple instances (common for DBs and stores):

```d2
db: { shape: cylinder; style.multiple: true }
```

See the full list: `d2 --help` / https://d2lang.com/tour/shapes/ (run `d2` locally for current set).

## Containers and Dot Notation

Braces group nodes. Children are addressed with dots — both for styling and for edges.

```d2
worker: {
  label: "worker machine"
  robotni: { label: "robotni\nFastAPI + ARQ" }
  workers: {
    pdf2md
    strukt2meta
    agentos
    ofs
  }
}

worker.robotni -> worker.workers: spawn
worker.workers.pdf2md -> store: write
```

- Container labels apply to the bounding box.
- Edges to a container draw to the container edge; edges to a child draw to that child.
- `label: "...\n..."` for multi-line text.

## Styles

Applied via `style.KEY: value` or a `style: { ... }` block.

```d2
a.style.fill: "#ffeecc"
a: { style.fill: blue; style.stroke: red; style.stroke-width: 3 }
a -> b: { style.animated: true; style.stroke-dash: 3 }
c.style.shadow: true
```

Useful keys: `fill`, `stroke`, `stroke-width`, `stroke-dash` (dashed line), `animated` (edge animation, SVG only), `shadow`, `opacity`, `border-radius`, `font-color`, `bold`, `italic`, `underline`, `width`, `height`.

Colors accept named colors or hex (`"#rrggbb"`).

## Special Objects

### Sequence diagram

```d2
seq: {
  shape: sequence_diagram
  client -> server: hello
  server -> db: query
  db -> server: rows
  server -> client: 200 OK
}
```

### SQL table

```d2
users: {
  shape: sql_table
  id: int { constraint: primary_key }
  email: varchar
  created_at: datetime
}
```

### Class

```d2
account: {
  shape: class
  + balance: float
  + deposit(amount): void
}
```

## Composition

Compose multiple **boards** into one `.d2`. Three keywords with different inheritance:

| Keyword | Inheritance | Use |
|---------|-------------|-----|
| `layers` | none (new base) | independent views, e.g. current vs proposed |
| `scenarios` | from base | alternatives on the same base, e.g. happy vs error |
| `steps` | from previous step | progression, animations |

```d2
layers: {
  current: { a -> b }
  proposed: { a -> b -> c }
}

scenarios: {
  happy: { a -> b: ok }
  error: { a -> b: fail }
}
```

- With composition, `d2 x.d2 outdir` produces one SVG **per board** under `outdir/`.
- Animate boards into one SVG: `d2 --animate-interval 1000 x.d2 out.svg` (SVG only).
- Render a single board: `d2 --target=layers.proposed x.d2 out.svg`. Trailing `.*` includes children.

## Layouts and Themes

Layouts available (bundled): `dagre` (default), `elk`. `tala` is paid.

```bash
d2 layout              # list available engines
d2 layout elk          # show elk options
```

Themes are integer IDs:

```bash
d2 themes              # list all theme IDs
```

| ID | Theme | | ID | Theme |
|----|-------|-|----|-------|
| 0 | Neutral Default | | 200 | Dark Mauve |
| 1 | Neutral Grey | | 201 | Dark Flagship |
| 3 | Flagship Terrastruct | | 300 | Terminal |
| 5 | Mixed Berry Blue | | 301 | Terminal Grayscale |
| 6 | Grape Soda | | 302 | Origami |
| 8 | Colorblind Clear | | 303 | C4 |

Set per-file (reproducible) or via flag:

```d2
vars: { d2-config: { layout-engine: elk; theme-id: 300 } }
```
```bash
d2 --layout=elk --theme=300 x.d2 x.svg
d2 --sketch x.d2 x.svg          # hand-drawn look
```

Dark-mode-aware: `--dark-theme <id>` switches theme when the viewer's browser is dark.
