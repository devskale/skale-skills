---
name: visualize
version: "1.13.0"
description: Explain or present with the smallest view that makes the point — inline code forms or one self-contained HTML page with a shareable URL. Hard style bans (enforced by the share gate): no colored card-edge accents (any side), no violet fills, no pills. Use when the user wants to visualize, compare, explain, or turn data/code into a page, diagram, or report.
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
2. **Build** — start from the skin: copy `templates/skin.html`, pick a flavor via
   `<body data-skin="paper|swiss|terminal|blueprint">` (paper = Editorial-Default,
   swiss = Stats/Vergleiche, terminal = Infra/CLI, blueprint = Architektur) and build
   inside it (tokens, type scale, card/legend/table patterns are already right — never
   blank CSS). Then set the output target, compose, and run `visualize gate <file>` —
   one command, all gates parallel (validate + slop + chartcheck; exit 1 if any fails).
   ([output.md](references/output.md) · [modules.md](references/modules.md) ·
   [html-patterns.md](references/html-patterns.md))
3. **Deliver** — open it and give the URL. ([output.md](references/output.md) → Sharing)

## Design principles

- **Visual first** — diagrams and layout carry the meaning; prose is sparse.
- **Scannable** — generous whitespace, neutral ink on warm paper, clear hierarchy.
- **Color is structure, not decoration** — category hues + `--ok/--warn/--bad` severity carry meaning.
- **Honest about scope** — if the user named a subset, visualize exactly that.
- **Be creative about the form** — templates are a floor, not a cage; pick the structure that reveals the mechanism.

## Hard style bans (the slop gate fails shares on these — don't generate them)

1. **No colored card accents — any edge, any side.** No `border-left/top/right/bottom:
   Npx solid <hue>` on cards/panels/callouts (inline or in CSS). This regenerates constantly
   because it *feels* like category structure — it is not. A card is a bordered box on
   paper; its category lives in the CONTENT: label text, small dot, severity hue on the
   value. Exception: neutral `--line` connectors that draw structure (timeline spine,
   tree guides).
2. **No violet/indigo fills** (`#5a4a8a`- to `#6366f1`-family backgrounds on buttons,
   badges, chips — muted counts too). Pick another hue for categories.
3. **No large colored circle badges** (≥20px `border-radius:50%` + colored background).
   Small dots (≤10px) and pill capsules are fine — pills are a taste call, the gate
   reports them as info only.

These cover what the gate flags as hardslop. Everything else the linter says
([promptlib.md §6 anti-patterns](references/promptlib.md)) is guidance, not gate.

Category color still carries meaning (e.g. a per-service hue on an infra page): keep it
as dot + label + value hue, and pick a flavor that gives it a home (`terminal` for
infra, `blueprint` for architecture). Fixing hardslop means moving hue to content —
never deleting the category distinction.

## Install

Ships in the **skale-skills** pi package — `pi install git:github.com/devskale/skale-skills`.
For a global `visualize` command, run this skill's `./install.sh` (Linux/macOS) or
`install.bat` (Windows).

## References

- **Decide:** [routing.md](references/routing.md) (d2/figure vs. inline) · [code-forms.md](references/code-forms.md) (smallest view first)
- **Design:** [structures.md](references/structures.md) (intents → stacks) · [patterns.md](references/patterns.md) (semantic patterns) · [modules.md](references/modules.md) (page modules) · [report.md](references/report.md) (report mode)
- **Polish:** [promptlib.md](references/promptlib.md) (design moves) · [inspirations.md](references/inspirations.md) (visual references)
- **Output:** [output.md](references/output.md) (targets, share/update) · [scaffolds.md](references/scaffolds.md) (template anatomy) · [html-patterns.md](references/html-patterns.md) (scaffold) · [chart-integrity.md](references/chart-integrity.md) (charts)
