---
name: improve-ux
description: Improve UI/UX of web interfaces by grounding every change in curated example sites and design references. Use when polishing a component, page, or design system - visual hierarchy, spacing, motion, empty states, accessibility, copy.
version: 0.2.0
---

# improve-ux

Improve a UI by grounding each change in concrete patterns from curated reference
sites — then record which sites earned their keep.

Taste comes **from the references**, not from memory alone. A change you cannot
cite is an opinion; cut it or find support for it. Wherever a standard or number
exists (WCAG, Material, DTCG), cite the **number**, not just the vibe.

## References

- [references/SITES.md](references/SITES.md) — curated example sites, grouped by focus
- [references/SOTA.md](references/SOTA.md) — the SOTA baseline: numeric WCAG 2.2 rules,
  DTCG token spec, motion durations/easing, empty-state & a11y-automation guidance

Read **SOTA.md first** on any task — it's the ground truth for "what good looks
like". Then pick sites from SITES.md for *visual* grounding.

## Workflow

### 1. Understand the target

What are you improving — component(s), page(s), flow? Note the stack
(React/Tailwind/shadcn/vanilla) and the goal: visual polish, motion, clarity,
accessibility. Ask the user only if genuinely ambiguous.

### 2. Pick references

Read [references/SITES.md](references/SITES.md) and the ratings file:

```
~/.cache/skale-skills/improve-ux/ratings.json   # may not exist yet
```

Choose 1–3 sites whose focus matches the task, preferring sites with a high
`helped` ratio. On the first run (no ratings yet), any listed site is fine.
Cross-check the relevant section of SOTA.md for the numeric standards you must
meet (contrast, target size, focus, motion duration).

### 3. Ground in real patterns

Fetch the chosen references (`fetch-url` skill or `curl`) and extract **concrete,
applicable patterns**: spacing scales, easing curves and durations, focus styles,
empty states, copy tone. Do not stop at vibes — name the pattern precisely enough
to implement it. For a11y, prefer automated verification (axe-core) over eyeballing.

### 4. Improve

Apply improvements to the actual code. Prefer small, reviewable changes. Each
change cites its source pattern — and the number where one exists — in one clause:

> Button target padded to 44×44 CSS px (per WCAG 2.5.5).
> Drawer slides 200ms ease-out (per emilkowal.ski/ui; exit faster at 150ms).

Verify visually where possible — screenshot via `rodney` — and run an automated
a11y check (axe-core) before calling it done.

### 5. Record

Update `~/.cache/skale-skills/improve-ux/ratings.json` (create if missing):

```json
{
  "sites": {
    "emilkowal.ski": { "uses": 3, "helped": 3, "note": "best for motion decisions" },
    "ui.shadcn.com": { "uses": 2, "helped": 1, "note": "shadcn stacks only" }
  }
}
```

For each site used this run: `uses += 1`, `helped += 1` only if it produced a
change you kept. High `helped`-ratio sites get picked first next time. If a site
keeps failing to help, say so and suggest dropping it from SITES.md.

## Adding sites

When the user names a new site: fetch it once to verify it loads and matches the
theme, append it to [references/SITES.md](references/SITES.md) with a one-line
description, and let it enter the normal rating loop.

## Rules

- **Numbers over vibes.** Where a standard exists, cite the number (WCAG 2.5.8
  target ≥24px, 2.4.13 focus ≥2px perimeter @ 3:1, 1.4.3 contrast 4.5:1, motion
  150–200ms desktop / ~300ms mobile, exits faster than entrances).
- **Accessibility is never optional:** contrast, visible focus (`:focus-visible`,
  never `outline: none`), target sizes, `prefers-reduced-motion`. Verify with
  axe-core, not just by eye.
- **Tokens:** prefer OKLCH for color ramps; express system-wide values as design
  tokens (DTCG format), not hardcoded literals.
- One source of truth per pattern: cite the site, do not restate its whole doc.
