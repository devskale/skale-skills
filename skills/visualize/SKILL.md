---
name: visualize
version: "1.0.0"
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
for a small graph embedded in a page. But some visualization challenges are **better
served by `d2` or `figure`**, and `visualize` should **say so and point the user there**
rather than force a mediocre inline diagram. You can't auto-invoke them (manual-only), so
you *recommend*; the user runs `/skill:d2` or `/skill:figure`.

**Recommend `d2` when the challenge is a complex technical graph:**

- **Sequence / ER / class diagrams** — structured, many nodes, precise syntax.
- **Dependency / call graphs** with many nodes and edges — d2's auto-layout (elk) handles
  them; hand-drawn inline SVG gets tangled fast.
- **A diagram that must be self-verifiable** — d2 renders to ASCII for structural
  verification, and to a version-controllable `.svg`/`.png`/`.pdf`.
- **The diagram is the deliverable** (to commit to the repo, embed in docs, export as
  PNG/PDF), not just one element in a throwaway page.

**Recommend `figure` when the user wants a hand-drawn, presentation-quality figure:**

- **Sketchy / Excalidraw-style explainer** — pipeline, workflow, architecture figure with
  a specific editorial look.
- **A polished figure for a slide / report / deliverable** — not an embedded page element.

**When visualize should just build it inline:** the diagram is simple (a few nodes), it's
*one element among many* in a page, and the user wants a quick shareable page — not a
standalone diagram file. Then inline SVG or Mermaid is the right call; don't bounce the
user to d2/figure for a trivial graph.

**How to recommend:** end the page with a short note, e.g. *"This graph is complex — for a
proper auto-laid-out diagram, run `/skill:d2`; for a hand-drawn figure, `/skill:figure`."*
Keep it one line; don't over-recommend.

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

**Then decide live whether this is a `visualize`/`report` job at all.** Read the `d2` and
`figure` skill descriptions (their `description` frontmatter is in the system-prompt
catalog) and decide which tool owns the challenge:

- If the core of the request is a **complex technical diagram** (sequence/ER/class,
  dependency graph, self-verifiable or deliverable diagram) → **recommend `/skill:d2`** and
  stop (don't build a weak inline version).
- If the user wants a **hand-drawn presentation figure** → **recommend `/skill:figure`**.
- Otherwise → build it yourself with `visualize` (cards, tree, system map, simple inline
  diagrams, etc.).

This is a **live decision per request**, not a rule — re-read the descriptions each time
and weigh the specific challenge. See *When to recommend d2 / figure* above for the full
decision boundary.

Pick the structure that fits (see [references/structures.md](references/structures.md)):
`overview-grid`, `cards`, `before-after`, `list`, `timeline`, `flow`, `comparison`,
`hierarchy`. Don't over-engineer — one strong structure beats a kitchen sink.

Then, when **building the page**, read [references/promptlib.md](references/promptlib.md) —
the prompt library of design moves that make a visualization *lovely* (colour-coded
grouping, editorial typography, card grids, provenance footer). It's the difference
between a fine page and one the user says is great.

### 2. Build — compose one self-contained HTML page

**Compose from page modules**, don't rebuild or pick a full template. Read
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
visualize validate <file.html>
```

It warns if you left an external `src`/`href` reference.

### 3. Deliver — open it and give the URL

```bash
visualize open  <file.html>    # show it in the browser
visualize share <file.html>    # upload to throway → prints the URL
```

Always give the user the **URL**. Note the throway URL **expires after ~4 hours** and is
**public** (anyone with the link can read it) — say so when sharing something sensitive.
Keep the local file too: it's the durable copy.

> **Bundle & dir capability (throway).** Throway supports more than single files:
> - **Bundles** — upload multiple files (`index.html` + `.css` + `.js` + assets) under one
>   URL via multipart POST to `https://lubu.skale.dev/throway/`. Bundle root serves
>   `index.html` inline to browsers (zip to agents); files at `/<id>/<filename>`.
> - **Dirs** — a **mutable, browseable folder**: create with `POST /?dir=1`, add files,
>   browse as an HTML listing page (or JSON for agents), download as zip, delete files.
>   Use `visualize share --dir <dir>` to publish a whole directory as a browseable throway
>   dir. Expires ~4h after the last add (max 24h).
>
> **Not the default:** the default stays one self-contained HTML (simplest, no UA split).
> Reach for a bundle when the visualization genuinely needs separate files (multi-page set,
> heavy per-file assets); reach for a dir when you want a *browseable folder of items*.
> MIME sniffing and relative-URL resolution are fixed on throway (verify when you depend
> on them).

## Design principles

- **One contained HTML** — the user's explicit want. Everything inline; the file is the
  deliverable.
- **Visual first** — diagrams and layout carry the meaning; prose is sparse. If a diagram
  needs a paragraph to be understood, redraw it.
- **Scannable** — generous whitespace, one accent colour, clear hierarchy. Editorial, not
  corporate-dashboard.
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
- [references/structures.md](references/structures.md) — high-level intents → which
  module stack fits
- [references/report.md](references/report.md) — **report mode**: a specific module
  composition (exec-summary + sections + recommendations)
- [references/promptlib.md](references/promptlib.md) — the prompt library of design moves
  for building *lovely* pages (colour grouping, editorial type, card grids, provenance)
- [references/html-patterns.md](references/html-patterns.md) — the HTML scaffold, inline
  CSS patterns, and diagram techniques
