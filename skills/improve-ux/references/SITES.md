# Curated UI/UX reference sites

The living list of example sites this skill grounds improvements in.
Add new sites via `improve-ux add <url> "<focus>" --group <heading>` (verifies
the URL, dedupes, appends). Bulk discovery: `improve-ux discover` — see
[SKILL.md](../SKILL.md) → *Keep the list fresh*.
Remove the `(unverified)` marker by fetching the site once (`fetch-url`) and
confirming the description.

Ratings (which sites actually helped) live OUTSIDE this file, in
`~/.cache/skale-skills/improve-ux/ratings.json`.

## Component galleries & libraries

| Site | Focus |
|------|-------|
| [beautifului.dev](https://beautifului.dev) | Crafted primitives for AI-native interfaces (verified 2026-09-12) |
| [beui.dev](https://beui.dev) | 109 animated React/Next.js components — Tailwind 4, Framer Motion, shadcn-distributed |
| [rareui.com](https://rareui.com) | Rare animated React components, one file each, shadcn-CLI installable |
| [ui.shadcn.com](https://ui.shadcn.com) | shadcn/ui — accessible React+Tailwind components, the default reference for shadcn stacks |
| [reui.io/components](https://reui.io/components) | Tailwind/React component registry, shadcn-style — free shadcn UI components (verified 2026-09-12) |
| [opensourceui.in](https://opensourceui.in) | Free MIT copy-paste library — 200+ production-ready React/Next.js components across 30 categories (audio, notifications, widgets, tables, socials, pricing, forms, mockups…), TypeScript + Tailwind v4, live previews + copy-to-clipboard source |
| [coss.com/ui](https://coss.com/ui) | Modern UI component library built on Base UI (verified 2026-09-12) |

## Craft, motion & taste

| Site | Focus |
|------|-------|
| [60fps.design](https://60fps.design/) | Animation inspiration clips for mobile & web apps (added 2026-09-12, web+X validated) |
| [lightswind.com](https://lightswind.com/components) | 100+ animated React components, Tailwind-based, blocks & templates (added 2026-09-12) |
| [motion.dev](https://motion.dev/ui) | Animated marketing sections from the Motion makers — skinnable via shadcn tokens (added 2026-09-12) |
| [www.hover.dev](https://www.hover.dev/) | Animated UI components & templates for React + TailwindCSS (added 2026-09-12) |
| [animate-ui.com](https://animate-ui.com/) | Free animated React + Tailwind components (Framer Motion), copy-paste (added 2026-09-12) |
| [transitions.dev](https://transitions.dev) | UI transitions for AI agents — examples with skill + refine tool (verified 2026-09-12) |
| [emilkowal.ski/ui/you-dont-need-animations](https://emilkowal.ski/ui/you-dont-need-animations) | Emil Kowalski: when motion helps and when it hurts. **Read before adding ANY animation.** |

## Audits & systems

| Site | Focus |
|------|-------|
| [designsystems.surf](https://designsystems.surf) | Design-system gallery + articles on what makes each system good (added 2026-09-12) |
| [designsystemsrepo.com](https://designsystemsrepo.com/design-systems/) | Directory of 100+ real design systems (Zendesk Garden, Yelp, Gympass Yoga…) with screenshots (added 2026-09-12) |
| [designsystemchecklist.com](https://designsystemchecklist.com) | Design-system audit checklist — great for structured reviews (verified 2026-09-12) |
| [ui-skills.com](https://ui-skills.com) | UI craft for design engineers — by ibelick (verified 2026-09-12) |

## Systems & real-world patterns

| Site | Focus |
|------|-------|
| [pageflows.com](https://pageflows.com/) | User-flow recordings from top apps — onboarding, upgrade, empty states (added 2026-09-12, web+X validated) |
| [refero.design](https://refero.design/) | Searchable UI flows & patterns from real apps — strong mobbin alternative (added 2026-09-12, web+X validated) |
| [carbondesignsystem.com](https://carbondesignsystem.com/patterns/empty-states-pattern/) | IBM Carbon empty-states pattern — anatomy, types, in-depth alternatives (added 2026-09-12) |
| [m3.material.io](https://m3.material.io) | Material Design 3 — Google's open-source design system: tokens, components, motion, a11y |
| [mobbin.com](https://mobbin.com) | Real-world UI patterns from 1000+ apps & 200 sites — great for screens/empty states |
| [easings.net](https://easings.net) | Easing-function picker for natural motion curves |

## Inspiration galleries (real sites & screens)

| Site | Focus |
|------|-------|
| [www.awwwards.com](https://www.awwwards.com/) | Award-winning web design — the reference for polished, top-tier sites (added 2026-09-12, web+X validated) |
| [www.siteinspire.com](https://www.siteinspire.com/) | Curated web-design gallery, filterable by style, type, industry (added 2026-09-12, web+X validated) |
| [land-book.com](https://land-book.com/) | Landing-page gallery with category filters (added 2026-09-12, web+X validated) |
| [onepagelove.com](https://onepagelove.com/) | One-page website gallery — examples + templates (added 2026-09-12, web+X validated) |
| [muz.li](https://muz.li/) | Design trend & pattern roundups (websites, landing pages, motion) (added 2026-09-12, web+X validated) |
| [www.toools.design](https://www.toools.design/) | The mega-directory of 100+ design inspiration sites & tools (added 2026-09-12, web+X validated) |

## Agent-skill collections (grounding for the whole review)

| Source | Focus |
|--------|-------|
| [github.com/jakubkrehel/skills](https://github.com/jakubkrehel/skills) | Collection of agent skills for building great interfaces — UI (border radius, optical alignment, hit areas, animation), typography, colors/palettes/contrast, accessibility, layout, product writing, plus interface-review, break (state stress-test) & variant skills |

## Ratings protocol

After each run, update `~/.cache/skale-skills/improve-ux/ratings.json`
(create if missing):

```json
{
  "sites": {
    "emilkowal.ski": { "uses": 3, "helped": 3, "note": "best for motion decisions", "verified": true },
    "ui.shadcn.com": { "uses": 2, "helped": 1, "note": "shadcn stacks only", "verified": true }
  }
}
```

- Per site used this run: `uses += 1`; `helped += 1` **only if it produced a
  change you kept**. Set `verified: true` once you've fetched it and confirmed
  the SITES.md description.
- High `helped`-ratio sites get picked first next time.
- If a site keeps failing to help, say so and suggest dropping it from this
  file.

## Adding sites

When the user names a new site: `improve-ux add <url> "<one-line focus>"
--group <heading>` (or append manually), then let it enter the normal rating
loop. Manual additions: fetch once with `fetch-url` to verify it loads and
matches the description before removing `(unverified)`.

| [muz.li](https://muz.li/) | Design trend & pattern roundups (websites, landing pages, motion) (added 2026-09-12, web+X validated) |
| [onepagelove.com](https://onepagelove.com/) | One-page website gallery — examples + templates (added 2026-09-12, web+X validated) |
| [land-book.com](https://land-book.com/) | Landing-page gallery with category filters (added 2026-09-12, web+X validated) |
| [www.siteinspire.com](https://www.siteinspire.com/) | Curated web-design gallery, filterable by style, type, industry (added 2026-09-12, web+X validated) |
| [www.awwwards.com](https://www.awwwards.com/) | Award-winning web design — the reference for polished, top-tier sites (added 2026-09-12, web+X validated) |
