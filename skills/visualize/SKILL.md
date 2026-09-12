---
name: visualize
version: "1.2.0"
description: "Render any set of things as ONE self-contained HTML document and give the user a URL — and generate polished HTML reports. Understands what you want (a codebase, modules, data, a plan, a comparison, an architecture, a set of items, or a structured report with findings), figures out the right structure, and builds a single portable HTML file — then opens it locally and optionally shares it to a short-lived URL via the throway store. Triggers on: visualize, make me a page, render this as HTML, show this as a diagram/page, turn this into a report, generate a report, give me a link to this, put it on a page."
---

# visualize — one self-contained HTML for any set of things

Turns a request into **one portable HTML document** that renders in any browser, then
gives the user a URL. Two modes:

- **Visualize** — display a set of things (cards, tree, system map, simple diagrams).
- **Report** — generate a structured document (executive summary, sections with findings,
  recommendations). See [references/report.md](references/report.md).

The whole point is **containment**: everything — styles, scripts,
diagrams, data — lives inside a single `.html` file. Nothing external, nothing to build,
nothing to host.

> **Related skills.** `d2` (auto-laid-out technical diagrams) and `figure` (hand-drawn
> presentation figures) are **manual-only** — invoke via `/skill:d2` / `/skill:figure`.
> `visualize` is the auto-invocable **page layer**: a page of many things, one
> self-contained HTML, shared to a URL.

## When to recommend d2 / figure (not build inline)

`visualize` builds its own simple diagrams inline (SVG arrows, optional Mermaid) — good
for a small graph embedded in a page. But some challenges are **better served by `d2`
(auto-laid-out technical diagrams) or `figure` (hand-drawn presentation figures)**. Both
are manual-only (`/skill:d2` / `/skill:figure`), so `visualize` **recommends and stops** —
don't build a weak inline version. Decide **live per request**, re-reading the `d2`/`figure`
descriptions (in the system-prompt catalog) each time:

- **→ `d2`** — complex technical graphs: sequence / ER / class diagrams; dependency or
  call graphs with many nodes and edges (elk auto-layout handles the density, inline SVG
  tangles); diagrams that must be self-verifiable (d2 renders ASCII) or are the
  deliverable (committed `.svg`/`.png`/`.pdf`), not just one element in a throwaway page.
- **→ `figure`** — hand-drawn presentation figures: sketchy Excalidraw-style explainers,
  polished figures for a slide / report / deck.
- **→ inline** — the diagram is simple (a few nodes), *one element among many*, and the
  user wants a quick shareable page. Don't bounce trivial graphs to d2/figure.

**Pattern-aware tripwire** (see [references/patterns.md](references/patterns.md)): a
pattern that is *at heart a dense technical graph* — fan-in queue, trust boundary, long
write-back loop — belongs in `d2` when the graph is the point, not one panel among many.
A pattern whose value is the *editorial sketch* — stage framework as a deck figure,
provenance trail — belongs in `figure`. If the real content exceeds the pattern's
complexity budget, that's the signal to hand it off.

**How to recommend:** end the page with one line, e.g. *"This graph is complex — for a
proper auto-laid-out diagram, run `/skill:d2`; for a hand-drawn figure, `/skill:figure`."*
Don't over-recommend.

## The shape of the job

The agent does three things, in order:

1. **Understand** — work out *what* the user wants and *which mode + structure* fits
   (visualize vs report; see [references/structures.md](references/structures.md) and
   [references/report.md](references/report.md)).
2. **Build** — write one self-contained HTML file to a temp dir (see Build below).
3. **Deliver** — `visualize open <file>` to show it, and `visualize share <file>` to get a
   URL. Give the user the URL.

## Workflow

### 1. Understand — decide the mode from the prompt, then the structure

The **mode** is decided by *what the user asked for* — report vs. visualization. Ask:

- **What is the subject?** A codebase? Modules? Data? A plan? A comparison? A set of items?
- **What is the point?** To explore, to decide, to present, to compare, to explain, to report?
- **What is the scope?** Everything, or a specific subset they named?

**Mode = report** when the deliverable is a *document* — findings, analysis, a narrative
with sections and recommendations. Prompt signals: "write me a report on X", "evaluate
Y", "summarise the audit", "assess these options", "findings + recommendations".
→ Follow [references/report.md](references/report.md).

**Mode = visualize** when the deliverable is a *display* of a set of things — a tree, a
system map, cards, a comparison. Prompt signals: "show me the repo", "compare these",
"map the platform", "visualize the data".
→ Pick a structure from [references/structures.md](references/structures.md).

A report can *embed* a visualization (a chart/map inside a section), but the mode is set
by the deliverable: a document → report; a display → visualize. Don't blur them.

**Then run the d2 / figure routing check** (*When to recommend d2 / figure* above):
complex technical diagram → recommend `/skill:d2` and stop; hand-drawn presentation
figure → recommend `/skill:figure`; otherwise build it here.

**First decide whether a semantic pattern owns the challenge.** When behaviour, state,
enforcement, or risk is load-bearing (work queues up, a boundary is crossed, a loop feeds
back, two things diverge), name the pattern first — see
[references/patterns.md](references/patterns.md) for the pattern catalogue, each with a
complexity budget and a static fallback. Pattern first, then structure.

Then pick the structure that fits (see [references/structures.md](references/structures.md)):
`overview-grid`, `cards`, `before-after`, `list`, `timeline`, `flow`, `comparison`,
`hierarchy`. Don't over-engineer — one strong structure beats a kitchen sink.

Then, when **building the page**, read [references/promptlib.md](references/promptlib.md) —
the prompt library of design moves that make a visualization *lovely* (colour-coded
grouping, editorial typography, card grids, provenance footer). It's the difference
between a fine page and one the user says is great.

### 2. Build — compose one self-contained HTML page

**Set the output target first** (see [references/output.md](references/output.md)): is this a
browser `page`, a `slide`, a `doc`/README, a `social` card, or `print`? `page` is the
default; the target changes canvas, density, and copy. Then:

**MANDATORY: read a default template first.** Before writing any HTML, `read` at least
one template from `templates/` (`cards.html`, `report.html`, `system-map.html`,
`repo-tree.html`, `mermaid.html`)
that matches the structure you chose. Start from its CSS + scaffold — do **not** hand-write
HTML/CSS from scratch. This is what keeps every page on the clean neutral house style
(no AI-generated accents). The templates are the proven starting point; compose from them,
never reinvent.

Then **compose from page modules**, don't rebuild from nothing. Read
[references/modules.md](references/modules.md) — the catalog of reusable modules
(`header`, `legend`, `card-grid`, `tree`, `flow`, `table`, `section`, `exec-summary`,
`recommendations`, `mermaid`, `footer`). Pick the modules that fit the request, stack them
inside the shared `<main>` base, and fill the placeholders. A report and a visualization
are both just different module compositions.

Write the HTML to the OS temp dir so nothing lands in the repo:

- Resolve from `$TMPDIR`, falling back to `/tmp` (or `%TEMP%` on Windows).
- Filename: `<slug>-<timestamp>.html`, e.g. `architecture-1699999999.html`.
- **Self-contained only** — no external stylesheets, scripts, images, or fonts.
  Inline everything with `<style>` and `<script>`. See
  [references/html-patterns.md](references/html-patterns.md) for the scaffold and patterns.
- If you use a CDN (Tailwind, Mermaid), that's a **runtime network dependency** — the file
  still works offline for content, but diagrams/styling degrade. Prefer inline CSS for the
  core so the document is truly portable. When a diagram genuinely needs Mermaid, use it,
  but keep the layout itself in inline CSS.

Validate before delivering:

```bash
visualize validate <file.html>   # self-contained: no external references
visualize lint <file.html>       # style taste-gate: flag AI-generated tells
visualize --selfcheck            # version, install dir, last update
visualize --update               # pull the latest skill via git
```

`validate` exits non-zero on external references (`src`/`href`, CSS `@import`/`url()`) —
**known CDNs are allowed** (`cdn.tailwindcss.com`, `cdn.jsdelivr.net`): a CDN-backed page
passes, but it's a runtime network dependency (content works offline, diagrams/styling
degrade — see the CDN note above). `lint` is the **style
taste-gate** — it flags the AI-slop tells from promptlib §0 (saturated accent on links,
colored pill badges, colored numbered-circle badges, colored `.ok`/`.bad` values) and
exits non-zero if any are found. Run both before sharing; fix the tells rather than
sharing a page that screams "generated".

### 3. Deliver — open it and give the URL

```bash
visualize open  <file.html>    # show it in the browser
visualize share <file.html>    # upload to throway → prints the URL
```

Always give the user the **URL**. Note the throway URL **expires after ~4 hours** and is
**public** (anyone with the link can read it) — say so when sharing something sensitive.
Keep the local file too: it's the durable copy.

> **Dir capability (throway).** Beyond single files, `visualize share --dir <dir>` publishes
> a whole directory as a **mutable, browseable throway folder** — HTML listing for
> browsers, JSON for agents, zip download; expires ~4h after the last add (max 24h). Use it
> when you want a *browseable folder of items*; the default stays one self-contained HTML.
> (Throway also supports multi-file bundles via raw multipart POST — read `/api` first; no
> launcher command, and verify MIME sniffing / relative-URL resolution when you depend on
> them.)

## Design principles

- **One contained HTML** — the user's explicit want. Everything inline; the file is the
  deliverable.
- **Visual first** — diagrams and layout carry the meaning; prose is sparse. If a diagram
  needs a paragraph to be understood, redraw it.
- **Scannable** — generous whitespace, neutral ink on warm paper, clear hierarchy.
  Editorial, not corporate-dashboard.
- **NO AI-generated accents.** Never use colored pill badges, colored `.ok`/`.bad` values,
  saturated accent links, or colored numbered-circle badges — they scream "LLM slop."
  See promptlib.md §0 for the full never-list. Numbers as plain muted text, links as ink
  with a hairline underline.
- **Honest about scope** — if the user named a subset, visualize exactly that; don't pad
  with everything else.

## Install

Ships in the **skale-skills** pi package — install the repo once:

```bash
pi install git:github.com/devskale/skale-skills
```

To also get a global `visualize` shell command, run from this skill's directory:

```bash
./install.sh        # → creates ~/.local/bin/visualize (Linux/macOS)
install.bat         # Windows, same directory
```

Requires `curl` (for `share`). `python3` improves URL parsing but is optional.

## References

- [references/modules.md](references/modules.md) — **the page-module catalog**: the
  reusable building blocks (header, legend, card-grid, tree, flow, table, section,
  exec-summary, recommendations, mermaid, footer) and how to compose a page from them
- [references/patterns.md](references/patterns.md) — **semantic patterns**: what the page
  *does* (fan-in queue, trust boundary, loop, divergence, …), each with a complexity
  budget + static fallback. Decide the pattern before the structure.
- [references/structures.md](references/structures.md) — high-level intents → which
  module stack fits
- [references/report.md](references/report.md) — **report mode**: a specific module
  composition (exec-summary + sections + recommendations)
- [references/promptlib.md](references/promptlib.md) — the prompt library of design moves
  for building *lovely* pages (colour grouping, editorial type, card grids, provenance)
- [references/output.md](references/output.md) — **where the page lands**: page / slide /
  doc / social / print presets, density, and getting a PNG for non-page targets
- [references/html-patterns.md](references/html-patterns.md) — the HTML scaffold, inline
  CSS patterns, and diagram techniques
- [references/inspirations.md](references/inspirations.md) — visual references worth
  studying / borrowing from (add as you find them)
