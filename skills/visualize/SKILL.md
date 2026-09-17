---
name: visualize
version: "1.6.0"
description: "Render any set of things as ONE self-contained HTML document and give the user a URL — and generate polished HTML reports. Understands what you want (a codebase, modules, data, a plan, a comparison, an architecture, a set of items, or a structured report with findings), figures out the right structure, and builds a single portable HTML file — then opens it locally and optionally shares it to a short-lived URL via the throway store. Triggers on: visualize, make me a page, render this as HTML, show this as a diagram/page, turn this into a report, generate a report, give me a link to this, put it on a page."
---

# visualize — one self-contained HTML for any set of things

Turns a request into **one HTML file** — content and layout inline, popular packages
(Mermaid, Tailwind) optionally via CDN — then gives the user a URL. Two modes:
**Visualize** (display a set of things: cards, tree, system map) and **Report** (a
structured document: exec summary, findings, recommendations —
[references/report.md](references/report.md)). `d2`/`figure` are manual-only
(`/skill:d2` / `/skill:figure`); when to hand off vs. build inline:
[references/routing.md](references/routing.md).

## Workflow

### 1. Understand — mode, then pattern, then structure

Mode = **report** when the deliverable is a *document* — "write a report", "evaluate",
"assess", "findings + recommendations" → [references/report.md](references/report.md).
Mode = **visualize** when it's a *display* of a set of things — "show the repo",
"compare", "map the platform" → structure from
[references/structures.md](references/structures.md). A report can *embed* a
visualization; the mode is set by the deliverable. Don't blur them.

Then the **d2 / figure routing check** ([references/routing.md](references/routing.md)):
complex technical diagram → recommend `/skill:d2` and stop; hand-drawn presentation
figure → recommend `/skill:figure`; otherwise build it here.

When behaviour, state, or risk is load-bearing, name the **semantic pattern** first
([references/patterns.md](references/patterns.md) — complexity budgets + static
fallbacks); then the structure: `overview-grid`, `cards`, `before-after`, `list`,
`timeline`, `flow`, `comparison`, `hierarchy`. One strong structure beats a kitchen sink.

### 2. Build — compose one HTML page

**Set the output target first** — `page` (default), `slide`, `doc`, `social`, `print`;
target changes canvas, density, and copy: [references/output.md](references/output.md).

**Instantiate, don't hand-roll.** Read the closest template (`cards`, `report`,
`system-map`, `repo-tree`, `mermaid`, `timeline`, `before-after`, `cheatsheet`,
`barchart` — all in `templates/`) for the scaffold — or compose from
page modules ([references/modules.md](references/modules.md)): copy the **shared base**
once (all module CSS lives there), then write **short class-based HTML** per module
(`header`, `legend`, `card-grid`, `tree`, `flow`, `table`, `section`, `exec-summary`,
`recommendations`, `mermaid`, `footer`). Never inline-duplicate styles per element.
When building, read [references/promptlib.md](references/promptlib.md) — the design moves that make a page *lovely*.

Write to the OS temp dir (`$TMPDIR` → `/tmp`, `%TEMP%` on Windows), filename
`<slug>-<timestamp>.html`:

- **One file** — no local sibling files (`style.css`, `app.js`, images). Inline content
  and layout; popular packages via popular CDNs, but keep the layout inline so content
  renders offline. See [references/html-patterns.md](references/html-patterns.md).

Validate before delivering: `visualize validate <file.html>` (one file: local refs fail,
popular CDNs ok) and `visualize lint <file.html>` (flags decorative AI-tells — saturated
accent links, pastel pills, large colored circles; structural color passes).
Launcher flags `--selfcheck` / `--update` per convention.

### 3. Deliver — open it and give the URL

`visualize open <file.html>` shows it; `visualize share <file.html>` uploads to throway
and prints the URL; `visualize share --dir <dir>` publishes a browseable folder.

Always give the user the **URL** — it **expires after ~4 hours** and is **public**
(anyone with the link can read); say so for sensitive content. Keep the local file: it's
the durable copy. `--dir` uploads **recursively**; throway dirs are flat, so nested
files are flattened (`sub/f.txt` → `sub-f.txt`). Default stays one self-contained HTML.

## Design principles

- **Visual first** — diagrams and layout carry the meaning; prose is sparse. If a diagram
  needs a paragraph to be understood, redraw it.
- **Scannable** — generous whitespace, neutral ink on warm paper, clear hierarchy.
  Editorial, not corporate-dashboard.
- **Color is structure, not decoration** — category hues and `--ok/--warn/--bad` severity
  carry meaning; never pastel pills, saturated links, big colored circles (promptlib §0–2).
- **Honest about scope** — if the user named a subset, visualize exactly that.

## Install

Ships in the **skale-skills** pi package — `pi install git:github.com/devskale/skale-skills`.
For a global `visualize` command, run this skill's `./install.sh` (Linux/macOS) or
`install.bat` (Windows). Needs `curl` (for `share`); `python3` optional (grep fallbacks).

## References

- [references/routing.md](references/routing.md) — **hand off to d2/figure or build inline?**
- [references/modules.md](references/modules.md) — the page-module catalog
- [references/patterns.md](references/patterns.md) — semantic patterns + complexity budgets
- [references/structures.md](references/structures.md) — intents → module stacks
- [references/report.md](references/report.md) — report mode
- [references/promptlib.md](references/promptlib.md) — design moves for *lovely* pages
- [references/output.md](references/output.md) — presets; [references/html-patterns.md](references/html-patterns.md) — scaffold + patterns
- [references/inspirations.md](references/inspirations.md) — visual references to study
