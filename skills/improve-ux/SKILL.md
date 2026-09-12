---
name: improve-ux
description: Improve UI/UX of web interfaces by grounding every change in curated example sites and design references. Use when polishing a component, page, or design system - visual hierarchy, spacing, motion, empty states, accessibility, copy.
version: 0.3.0
---

# improve-ux

Improve a UI by grounding each change in concrete patterns from curated reference
sites and numeric standards — then record what helped, so both the reference
list and the target's progress get better run over run.

Taste comes **from the references**, not from memory alone. A change you cannot
cite is an opinion; cut it or find support for it. Where a standard exists
(WCAG, Material, DTCG), cite the **number**, not the vibe.

## Topic router — load only what the task needs

| Task | Read first |
|------|------------|
| Accessibility pass | [references/sota/a11y.md](references/sota/a11y.md) |
| Animation / transitions | [references/sota/motion.md](references/sota/motion.md) |
| Colors, tokens, theming | [references/sota/tokens.md](references/sota/tokens.md) |
| Empty / loading states | [references/sota/states.md](references/sota/states.md) |
| Choosing a11y tooling | [references/sota/tooling.md](references/sota/tooling.md) |
| Any visual grounding | [references/SITES.md](references/SITES.md) — pick 1–3 sites by focus + `helped` ratio |
| Whole-review / deep dive | [references/deep-review.md](references/deep-review.md) — external skill bundle |

Never load every topic file "to be safe" — route, then read.

## Workflow

### 1. Understand the target
Component(s), page(s), flow? Stack, goal? **Check for an existing findings
ledger first** ([references/ledger.md](references/ledger.md)) — continue the
last pass instead of restarting from zero. Ask only if genuinely ambiguous.

### 2. Route & pick references
Topic router above → read that one file. Then pick 1–3 sites from SITES.md,
preferring high `helped` ratio (ratings protocol lives there).

### 3. Ground in real patterns
Fetch the chosen sites (`fetch-url` / curl); extract concrete, applicable
patterns — spacing scales, easing curves, focus styles, copy tone. Name each
pattern precisely enough to implement it.

### 4. Improve — priority ladder, capped
Order: **a11y blockers** → **structure & hierarchy** → **interaction & motion**
→ **copy & polish**. Stop or defer when a pass gets big (≤ ~7 kept changes);
deferred items go to the ledger. Every change cites its source in one clause:

> Button target padded to 44×44 CSS px (per WCAG 2.5.5).

### 5. Verify
[references/verify.md](references/verify.md) — before/after screenshots via
`rodney`, plus axe-core for a11y. Not done until verified.

### 6. Record
- **Sites:** update ratings (protocol in SITES.md) — `helped` only for changes kept.
- **Target:** update the findings ledger — statuses, severities, deferred items
  become the next pass's starting point.

## Keep the list fresh (update feature)

```bash
improve-ux discover [--x]     # web-search (and X via peep) for new UX reference sites
improve-ux add <url> "<focus>" --group <heading>   # verify + append to SITES.md
```

`discover` prints candidate rows (deduped against SITES.md and the discovery
cache, reachability-checked). Curate: pick sites that fill a gap, fetch once,
write a one-line focus, `add` them under the fitting group. Queries are
editable: [references/discovery-queries.txt](references/discovery-queries.txt).

## Rules

- Numbers over vibes; cite the criterion — full tables live in the topic files.
- Accessibility is never optional; verify with axe-core, not by eye.
- Prefer OKLCH ramps + DTCG tokens over hardcoded literals.
- One source of truth per pattern: cite, don't restate.
- Small reviewable diffs; defer the rest to the ledger.
