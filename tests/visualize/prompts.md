# visualize — test prompts

Live prompt suite: one prompt per **template** (P1–P5), plus module-composition,
routing, output-target, and share-safety prompts. The launcher tests cover the plumbing
(validate / lint / share); these cover the **agent path** — picking the right template,
composing from modules, routing to d2/figure, targeting output, sharing safely.

## How to run

1. Fresh agent session with the skill active; cwd = this repo (or any real subject).
2. Paste the prompt **verbatim**.
3. Check **Expect**, then on the produced file run `visualize validate <file>` and
   `visualize lint <file>` — both must exit 0 — and eyeball via `visualize open <file>`.

Every produced page must be: **one self-contained HTML** · real content (no shipped
`{{placeholders}}`) · provenance `footer` · house style (class-based HTML from the shared
base, no inline-duplicated styles).

## Templates (one prompt per template)

| # | Prompt (verbatim) | Expect | Pass when |
|---|---|---|---|
| P1 | "Visualize the skills in this repo as a card grid, grouped by category." | visualize · cards · **`cards.html`** | `header` + `legend` + `card-grid` + `footer`; real skills; categories as plain muted text |
| P2 | "Show me what's in this repo as an annotated tree." | visualize · hierarchy · **`repo-tree.html`** | `tree` rows annotated (name + one-line + kind); deep dirs collapsed |
| P3 | "Map this platform: orchestrator repo, its sub-repos, the pipeline, and the fleet." | visualize · system-map · **`system-map.html`** | multi-panel (topology, pipeline, fleet, tree) — only panels that fit |
| P4 | "Write a report on test coverage in this repo: findings and prioritized recommendations." | **report** · **`report.html`** | `exec-summary` first, numbered `section`s, `recommendations` with priorities |
| P5 | "Show the request flow through the stack as a dependency graph." | visualize · graph · **`mermaid.html`** | `mermaid` via CDN inside a card; page layout stays inline CSS |
| P14 | "Show this year's release history as a timeline with phases." | visualize · sequence · **`timeline.html`** | spine + type dots matching the legend; one `now` marker |
| P15 | "Show before vs after the migration — removed, added, and which rules now pass." | visualize · change · **`before-after.html`** | −/+ deltas with symbols AND hues; paired trace marks first divergence |
| P16 | "Make me a cheatsheet for the visualize CLI." | visualize · reference · **`cheatsheet.html`** | command chips + one-line descriptions; topics grouped with hue dots |
| P17 | "Compare test suite sizes across the skills as a bar chart." | visualize · data · **`barchart.html`** | pure CSS bars, width ∝ value, ONE accent bar, values as text |

## Module composition (no matching template — must compose from the modules.md base)

| # | Prompt (verbatim) | Expect | Pass when |
|---|---|---|---|
| P6 | "Show this year's release roadmap as a timeline." | compose | shared base copied once + short class-based HTML; no template forced |
| P7 | "Compare the three hosting options side by side." | compose · `table` | one `table`; recommended option highlighted |
| P8 | "Show the CI pipeline as numbered steps." | compose · `flow` | `flow` steps numbered, arrows between |

## Routing (must recommend and stop — no weak inline build)

| # | Prompt (verbatim) | Expect | Pass when |
|---|---|---|---|
| P9 | "Draw the OAuth handshake as a sequence diagram — it's dense." | → `/skill:d2` | recommends d2; does NOT build an inline tangle |
| P10 | "Make a hand-drawn architecture figure for my deck intro." | → `/skill:figure` | recommends figure; does NOT build inline |

## Output targets & share safety

| # | Prompt (verbatim) | Expect | Pass when |
|---|---|---|---|
| P11 | "One 16:9 deck slide: Q3 results at a glance." | target=slide-16x9 | one viewport, no scroll, bigger type; PNG offered |
| P12 | "A social preview card for the release post." | target=social-og | ~1200×630, one strong message, PNG @2 |
| P13 | "Visualize the internal audit findings and share the link." | share | warns: URL is **public**, expires ~4h; keeps the local file |

> `tests/visualize/test.sh` greps this file for coverage: every template file, every
> module name, both routing targets, and an output target must appear above.
