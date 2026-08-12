# visualize templates

Ready-to-use, self-contained HTML templates. The agent copies one, fills in the `{{PLACEHOLDERS}}`,
and adapts. Each is the proven "house style" — start from a template rather than rebuilding.

## Which template to use

| Template | Style | Best for | Notes |
|----------|-------|----------|-------|
| [`cards.html`](cards.html) | Inline CSS, editorial | A set of things (cards, categories) | Zero external deps, fully self-contained · clean neutral house style |
| [`repo-tree.html`](repo-tree.html) | Inline CSS, editorial | Annotated repo / folder tree | Nested rows + connector lines, muted kind text |
| [`system-map.html`](system-map.html) | Inline CSS, editorial | Multi-repo / multi-service platform | Multi-panel: topology, pipeline, fleet |
| [`report.html`](report.html) | Inline CSS, editorial | A structured document | Kicker, exec summary, numbered sections, recommendations, TOC |
| [`mermaid.html`](mermaid.html) | **Tailwind + Mermaid (CDN)** | Graph-shaped content, polished Pocock-style | Loads Tailwind + Mermaid from CDN — needs network; use for complex graphs |

## Two style families

- **Inline-CSS templates** (`cards`, `repo-tree`, `system-map`, `report`) — zero external
  deps, work fully offline, truly self-contained. Use these by default.
- **Mermaid template** (`mermaid.html`) — Tailwind + Mermaid from CDN. Use when the content
  is genuinely graph-shaped (flow, dependency, sequence) and the polish is worth the network
  dependency. Adapted from the Pocock `improve-codebase-architecture` HTML-report scaffold.

## Rules

- **Always fill placeholders** (`{{...}}`) with real content — never ship placeholders.
- **Keep it self-contained** unless using `mermaid.html` (which needs CDN by design).
- **Validate** before sharing: `visualize validate <file.html>`.
- The provenance footer (how it was built + throway note) stays in every template.
