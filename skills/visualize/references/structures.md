# Visualization structures

The catalogue of ways to lay out a set of things in one self-contained HTML page.
Pick ONE that fits the subject + intent. Don't combine structures unless the content
is genuinely two-sided (e.g. before/after comparison).

> **Before choosing a structure**, check [patterns.md](patterns.md). When behaviour,
> state, enforcement, or risk is the point (work queues up, a boundary is crossed, a
> loop feeds back, two things diverge), a *semantic pattern* owns the challenge and maps
> to one of these structures. Pattern first, then structure.

## Choosing a structure

| Subject / intent | Structure |
|------------------|-----------|
| A set of distinct items, each with its own details | `cards` |
| Many items, quick scan, uniform | `overview-grid` |
| "Before vs after", "X vs Y", a change | `before-after` |
| A sequence of steps, a process, a roadmap | `timeline` |
| A curated list with rank/annotations | `list` |
| Dependencies, call graph, flow between things | `flow` |
| Parent/child, nesting, containment | `hierarchy` |
| Two or more options side by side | `comparison` |
| Multi-repo / multi-service orchestration, a platform, a fleet | `system-map` |

## Cards

Each item is a card with a title, a short body, and optional metadata (tags, numbers).
Best for heterogeneous items where each deserves its own space.

- Title row, then a few lines of body, then a metadata footer.
- Category goes as **plain muted text** in the footer — no colored pill badges (those read as
  AI-generated). A category legend is a quiet text line, not colored swatches.
- Grid of cards (`grid-template-columns: repeat(auto-fill, minmax(280px, 1fr))`).
- **Default:** use `templates/cards.html` which is already the clean neutral house style.

## Overview grid

Uniform tiles, minimal text — best for "here's everything at a glance."
Each tile is a small labelled box. Hover can reveal a tooltip with one line.

## Before / after

Two columns side by side, usually with a change or delta between them.
The centrepiece of a "what would change" visualization.

- "Before" left, "After" right.
- Keep each column ~320px tall so they sit comfortably without scrolling.
- Use colour to highlight what *changed* (e.g. red = removed, emerald = added).

## Timeline

A vertical or horizontal sequence of steps/phases, each with a label + one line.
Good for plans, roadmaps, processes, release notes.

- Vertical line with dots; each entry to the right.
- Add a "now" marker or phase grouping when it helps.

## List

A ranked or curated list, each row with a rank, a name, and an annotation.
Good for "top N", "recommendations", "the things, in order".

- Numbered rows, name in a medium weight, annotation in muted text.
- Optional: a reason column for recommendations.

## Flow

Graph-shaped relationships: dependencies, call graphs, sequences.
Use when the point is "X connects to Y connects to Z."

- If the graph is small and stable, hand-draw boxes + inline SVG arrows.
- If it's complex, Mermaid (see html-patterns.md) — but keep the page layout in inline CSS.

## Hierarchy

Nesting/containment: parent → child, tree, folder structure, org chart.
- Nested boxes with indentation, or a tree with connecting lines.
- Collapse interactions are a nice-to-have, not required — the page must render statically.
- **For a repo/`tree` view:** use the *annotated tree* — indented rows with a name,
  one-line description, and colour-coded kind tag (skill/ext/docs/…). See
  [promptlib.md](promptlib.md) §8 for the full recipe and CSS.

## Comparison

Two or more options side by side, each with the same set of attributes.
- A table or aligned columns; rows are attributes, columns are options.
- Highlight the recommended option.

---

## System map

For a **multi-repo / multi-service / multi-machine platform** — an orchestrator with
sub-repos, a server fleet, a pipeline. A single flat tree undersells this; a *system map*
shows how the parts relate. Usually **several panels in one page**, each a different lens:

1. **Repo topology** — the metarepo box containing its sub-repos, each annotated with role
   (frontend/backend/lib/data) + deploy target.
2. **Pipeline / data flow** — the end-to-end flow as horizontal steps (upload → … → review).
3. **Fleet / topology** — the servers/machines and what runs where.
4. **Tree (top level)** — the orchestration skeleton (CLI, central config, sub-repos, docs).

Pick the panels that fit the platform — not all four always apply. See
[promptlib.md](promptlib.md) §9 for the full recipe and CSS.

---

## Anti-patterns

- **Kitchen sink** — don't cram every structure into one page. One strong structure.
- **Generic dashboard** — avoid corporate chrome, heavy borders, dense tables of numbers.
  Editorial and scannable instead.
- **Prose-heavy** — the visuals carry the meaning. Cut paragraphs to bullets.
- **External deps for the core** — the layout must work from inline CSS alone.
