---
name: visualize
version: "1.0.0"
description: "Render any set of things as ONE self-contained HTML document and give the user a URL. Understands what you want to visualize (a codebase, modules, data, a plan, a comparison, an architecture, a set of items), figures out the right structure, and builds a single portable HTML file — then opens it locally and optionally shares it to a short-lived URL via the throway store. Triggers on: visualize, make me a page, render this as HTML, show this as a diagram/page, turn this into a report, give me a link to this, put it on a page."
---

# visualize — one self-contained HTML for any set of things

Turns a request into **one portable HTML document** that renders in any browser, then
gives the user a URL. The whole point is **containment**: everything — styles, scripts,
diagrams, data — lives inside a single `.html` file. Nothing external, nothing to build,
nothing to host.

## The shape of the job

The agent does three things, in order:

1. **Understand** — work out *what* the user wants to visualize and *which structure* fits
   (see [references/structures.md](references/structures.md) for the catalogue).
2. **Build** — write one self-contained HTML file to a temp dir (see Build below).
3. **Deliver** — `visualize open <file>` to show it, and `visualize share <file>` to get a
   URL. Give the user the URL.

## Workflow

### 1. Understand — figure out what they want

Clarify only if genuinely ambiguous; otherwise make a confident default. Ask yourself:

- **What is the subject?** A codebase? Modules? Data? A plan? A comparison? A set of items?
- **What is the point?** To explore, to decide, to present, to compare, to explain?
- **What is the scope?** Everything, or a specific subset they named?

Pick the structure that fits (see [references/structures.md](references/structures.md)):
`overview-grid`, `cards`, `before-after`, `list`, `timeline`, `flow`, `comparison`,
`hierarchy`. Don't over-engineer — one strong structure beats a kitchen sink.

### 2. Build — one self-contained HTML file

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

- [references/structures.md](references/structures.md) — the catalogue of visualization
  structures and how to pick one
- [references/html-patterns.md](references/html-patterns.md) — the HTML scaffold, inline
  CSS patterns, and diagram techniques
