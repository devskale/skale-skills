# Template scaffolds — the anatomy of each template

A **scaffold** is the fixed skeleton of a page: which blocks exist, what each block
carries, and which rules bind the filling. The templates in [`templates/`](../templates/)
are the executable form; this doc is the blueprint — read it to decide *what a page of
this kind consists of*, then copy the template and fill it.

Every scaffold shares the house frame: **kicker → h1 → sub → meta/legend → sections →
provenance footer**. The differences are the section bodies. Filling rules that bind all
of them live in [modules.md](modules.md) (the base) and [promptlib.md](promptlib.md)
(§6 anti-patterns); each scaffold below adds only what is specific to it.

## cards.html — "a set of things"

- One `section` per category, each a `grid` of `article.card`s.
- Card anatomy: `h3` title → `p` body (≤3 lines) → footer `cat` (category dot + plain
  muted text).
- Fill: one real item per card, the item's own terms for the title. No summary cards, no
  "overview" card that just introduces the grid.
- Legend mirrors the category hues exactly — a legend entry without cards (or vice versa)
  is a bug.

## repo-tree.html — annotated hierarchy

- One `tree` of `row`s: `ic` (indent/connector glyphs) → `name` (dir bold) → `desc`
  (one line, muted) → `kind` tag.
- `connector` nesting is indentation, not boxes — depth reads as structure.
- Fill: collapse deep dirs that contain nothing relevant (a tree is a claim about what
  matters, not an `ls -R`). `kind` colors from the category hues.

## system-map.html — the multi-panel platform

- Panels in order: **topology** (orchestrator + sub-repos, role annotations) →
  **pipeline** (horizontal end-to-end steps) → **fleet** (what runs where) → **tree**
  (orchestration skeleton). Pick the panels that fit — usually 3 of 4, never all by
  default.
- Fill: each panel is a lens on the *same* platform; the same component keeps the same
  hue across panels.

## report.html — the structured document

- `exec-summary` first (findings as bold-lead bullets), then numbered `section`s, then
  `recs` (ordered, prioritised), optional `toc` when long.
- Fill: findings first, evidence after. One sentence per finding lead — the reader gets
  the gist from the summary alone. Detail rules: [report.md](report.md).

## mermaid.html — graph-shaped content

- `mermaid-card`s (white card, scrollable) each holding one `pre.mermaid` graph;
  hand-built `card`s for everything non-graph.
- The scaffold ships `.seam`/`.leak`/`.deep` classDef helpers — diagram semantics, colour
  only where it carries meaning.
- Fill: Mermaid for the graphs, divs for editorial visuals — mix, never all-Mermaid
  ([html-patterns.md](html-patterns.md)). Needs network (CDN).

## tailwind-report.html — Pocock-style report on the Tailwind track

- `tailwind.config` maps house tokens as first-class colors — utilities read semantic
  (`text-ink`, `bg-paper`, `text-ok`). Critical CSS keeps the first paint on paper.
- Candidate `article` anatomy: `h3` title → strength (dot + severity text, never pills) →
  files (mono, muted) → before/after grid → problem/change one-liners → wins (`≤6`
  words, subject's own terms).
- Fill the before/after columns with diagram vocabulary from [structures.md](structures.md)
  (cross-section, mass diagram, collapse). Needs network (CDN).

## timeline.html — a sequence

- One vertical `timeline` of `tl` entries (type dot in legend hue → label → one-line
  note), grouped by `phase`, optional `now` marker on the current entry.
- Fill: entries in strict order; the `now` marker is a claim ("we are here"), place it
  once. One line per entry — an entry that needs two lines is two entries.

## before-after.html — what would change

- Two `ba-col`s with a `delta` between them; row states `keep`/`add`/`del` in severity
  hues. The paired-trace variant marks the **first divergence** — label it once.
- Fill: same rows on both sides, aligned — the reader compares row by row. Red = removed,
  emerald = added, muted = unchanged. Detail rules: [structures.md](structures.md).

## cheatsheet.html — dense CLI reference

- `topic` sections (hue dot + title), each a list of `cmd` chips (mono, the command) with
  a one-line description.
- Fill: the command verbatim as it is typed — no paraphrase. Group by task, not by flag.
  One line per command; a command that needs a paragraph is a page, not a cheat.

## barchart.html — data comparison, zero JS

- `chart` of `bar-row`s: label → `bar` (width ∝ value) → value as text; `hl` marks the
  one accent bar, `note` carries the unit/scale.
- Fill: values as text always (colour alone is not data); one accent max. Integrity
  rules: [chart-integrity.md](chart-integrity.md).

---

**The rule that governs all scaffolds:** if a block needs a paragraph of explanation to be
understood, the block is wrong — redraw it. The scaffold is a floor, not a cage: when the
subject needs a different form, say so and build that form (the templates are a starting
point, not a contract — [promptlib.md](promptlib.md) §6.5).
