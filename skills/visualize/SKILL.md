---
name: visualize
version: "1.9.0"
description: Explain or present with the smallest view that makes the point — inline code forms or one self-contained HTML page with a shareable URL. Use when the user wants to visualize, compare, explain, or turn data/code into a page, diagram, or report.
---

# visualize — one self-contained HTML for any set of things

Turns a request into **one HTML file** (content + layout inline, popular packages via CDN)
and gives the user a URL. Two modes: **Visualize** (a display of a set of things) and
**Report** (a structured document). `d2`/`figure` are manual-only — hand off to them, don't
build inline ([routing.md](references/routing.md)).

**Not every answer needs a page.** Pseudocode, a call tree, a component tree, or a
matched-shape diff often answers better and smaller ([code-forms.md](references/code-forms.md)).

## Workflow

1. **Understand** — does this need a page? If so, is it a *report* or a *visualize*? Then
   name the semantic pattern, then the structure. ([report.md](references/report.md) ·
   [patterns.md](references/patterns.md) · [structures.md](references/structures.md))
2. **Build** — set the output target, compose one self-contained HTML (template or modules),
   validate + lint. ([output.md](references/output.md) · [modules.md](references/modules.md) ·
   [html-patterns.md](references/html-patterns.md))
3. **Deliver** — open it and give the URL. ([output.md](references/output.md) → Sharing)

## Design principles

- **Visual first** — diagrams and layout carry the meaning; prose is sparse.
- **Scannable** — generous whitespace, neutral ink on warm paper, clear hierarchy.
- **Color is structure, not decoration** — category hues + `--ok/--warn/--bad` severity carry meaning.
- **Honest about scope** — if the user named a subset, visualize exactly that.
- **Be creative about the form** — templates are a floor, not a cage; pick the structure that reveals the mechanism.

## Install

Ships in the **skale-skills** pi package — `pi install git:github.com/devskale/skale-skills`.
For a global `visualize` command, run this skill's `./install.sh` (Linux/macOS) or
`install.bat` (Windows).

## References

- **Decide:** [routing.md](references/routing.md) (d2/figure vs. inline) · [code-forms.md](references/code-forms.md) (smallest view first)
- **Design:** [structures.md](references/structures.md) (intents → stacks) · [patterns.md](references/patterns.md) (semantic patterns) · [modules.md](references/modules.md) (page modules) · [report.md](references/report.md) (report mode)
- **Polish:** [promptlib.md](references/promptlib.md) (design moves) · [inspirations.md](references/inspirations.md) (visual references)
- **Output:** [output.md](references/output.md) (targets, share/update) · [html-patterns.md](references/html-patterns.md) (scaffold) · [chart-integrity.md](references/chart-integrity.md) (charts)
