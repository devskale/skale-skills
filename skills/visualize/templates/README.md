# visualize templates

Ready-to-use, self-contained HTML templates. The agent copies one, fills in the `{{PLACEHOLDERS}}`,
and adapts. Each is the proven "house style" — start from a template rather than rebuilding.
The anatomy of each (which blocks exist, what they carry, the filling rules) is documented
in [../references/scaffolds.md](../references/scaffolds.md).

## Which template to use

| Template | Style | Best for | Notes |
|----------|-------|----------|-------|
| [`cards.html`](cards.html) | Inline CSS, editorial | A set of things (cards, categories) | Zero external deps, fully self-contained · clean neutral house style |
| [`repo-tree.html`](repo-tree.html) | Inline CSS, editorial | Annotated repo / folder tree | Nested rows + connector lines, muted kind text |
| [`system-map.html`](system-map.html) | Inline CSS, editorial | Multi-repo / multi-service platform | Multi-panel: topology, pipeline, fleet |
| [`report.html`](report.html) | Inline CSS, editorial | A structured document | Kicker, exec summary, numbered sections, recommendations, TOC |
| [`mermaid.html`](mermaid.html) | **Mermaid (CDN)** | Graph-shaped content, polished Pocock-style | Loads Mermaid from CDN — needs network; use for complex graphs |
| [`pele.html`](pele.html) | **pele (CDN)** | Graph-shaped content, Mermaid syntax | Mermaid syntax via pele (MIT, Obsidian) — 6× smaller, themeable via CSS variables mapped to house tokens; needs network; check the [compatibility matrix](https://pele.run/compatibility) for exotic types |
| [`tailwind-report.html`](tailwind-report.html) | **Tailwind (CDN)** | Irregular report layouts, Pocock-style candidate cards | Utilities as syntax, house tokens as vocabulary (config maps ink/paper/severity); critical CSS kills the flash; needs network |
| [`timeline.html`](timeline.html) | Inline CSS, editorial | Sequence: roadmap, changelog, phases, history | Vertical spine + type dots (legend hue) + `now` marker |
| [`before-after.html`](before-after.html) | Inline CSS, editorial | Migration, refactor, "what would change" | Two-column −/+ delta + paired trace with first-divergence marker |
| [`cheatsheet.html`](cheatsheet.html) | Inline CSS, monospace commands | Dense CLI / tool reference | Command chips + one-line descriptions, topic groups with hue dots |
| [`barchart.html`](barchart.html) | Inline CSS, **zero JS** | Data comparison | Pure CSS bars — width ∝ value, one accent bar, values as text |

## Two style families

- **Inline-CSS templates** (`cards`, `repo-tree`, `system-map`, `report`) — zero external
  deps, work fully offline, truly self-contained. Use these by default.
- **CDN templates** (`mermaid.html`, `pele.html`, `tailwind-report.html`) — one library loaded from
  CDN at view time. Network at view time is the accepted contract (a shared URL is a web
  page like any other). Use when the content is genuinely graph-shaped (Mermaid/pele) or the
  per-page layout is irregular enough that utilities beat the inline module catalog
  (Tailwind). The Tailwind track keeps the house tokens as semantic classes
  (`text-ink`, `bg-paper`, `text-ok`) via its inline `tailwind.config` — the house rules
  (dot + muted text categories, severity only where colour IS the data) apply
  unchanged. Pills are a taste call, not a gate (the linter reports them as info).
- `pele.html` is the diagram default when the page should feel like the house: it accepts
  the same Mermaid syntax but themes through CSS variables mapped onto the house tokens
  (`--pele-bg: var(--paper)` …), so diagrams recolor with the skin without re-render.
  Prefer it over `mermaid.html` unless you need Mermaid-specific features (ZenUML, HTML
  labels) — pele's layout and limits differ; see [pele compatibility](https://pele.run/compatibility).
- `mermaid.html` is adapted from the Pocock `improve-codebase-architecture` HTML-report
  scaffold; `tailwind-report.html` adopts its Tailwind scaffold directly.

## Rules

- **Always fill placeholders** (`{{...}}`) with real content — never ship placeholders.
- **One file** — inline everything, or load popular packages from a CDN (`mermaid.html`
  does by design). No local sibling files.
- **Validate** before sharing: `visualize validate <file.html>`.
- The provenance footer (how it was built + throway note) stays in every template.
