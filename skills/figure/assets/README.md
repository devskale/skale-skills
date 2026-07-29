# assets/ — reusable icons & images

Shared building blocks for thesis figures. **Reuse before redrawing.** Everything here
should follow the house style in `../styleguide/SKILL.md`.

> **Publishable-without-attribution only.** Every asset here must be self-made, CC0 /
> public domain, or an OFL font. No CC-BY, no "free for personal use", no vendor logos.
> See `../LICENSING.md`. If an asset's **License** column is blank, treat it as
> unpublishable until verified.

## Layout

- `icons/` — small reusable icons (SVG preferred). One concept per file.
- `images/` — larger reusable illustrations or exported sub-diagrams.
- `fonts/` — the house font **Patrick Hand** (`PatrickHand-Regular.ttf`, OFL, with
  `OFL.txt`). The single font for every figure — titles, labels, badges. **No sans, ever;**
  SVG/CSS font stacks must end in `cursive`, not `sans-serif` (see `../styleguide/SKILL.md` §3).

## PNG alongside every SVG

Every SVG here ships with a **matching PNG** (same name) so results are viewable anywhere —
phone, image preview, PDFs that can't embed SVG. SVG is the source of truth; the PNG is a
generated preview at 4× scale, transparent background.

Regenerate after adding or editing any SVG:

```
cd figure && npm run icons                                             # normal machines (see build/README.md setup)
NODE_PATH=/opt/node22/lib/node_modules node figure/assets/render_pngs.mjs figure/assets   # this sandbox
```

`render_pngs.mjs` walks for `*.svg`, loads the Patrick Hand house font (so text never falls
back to sans), and writes a `*.png` next to each. Pass a directory to limit the scope.

## Naming

`role-descriptor.svg`, lowercase, hyphenated — e.g. `llm-agent-brain.svg`,
`vector-db-cylinder.svg`, `doc-envelope.svg`, `globe-internet.svg`, `code-tools.svg`.

## Icon manifest

Add a row whenever you add an icon so the next figure can find it. **License and Source
are mandatory** — only `self-made`, `CC0`, `public-domain`, or `OFL` are publishable.

All icons below are **self-made and released CC0** (see `LICENSE-CC0.txt`) — publishable
with no attribution. They are **generic** (no vendor logos/trademarks). Source viewBox is
`0 0 120 120` (badge `0 0 60 60`); recolour by editing `stroke`/`fill`.

| File | Role / meaning | Colour | License | Source |
|------|----------------|--------|---------|--------|
| `icons/llm-agent-brain.svg` | LLM Agent (decides) | red `#E8443A` | CC0 (self-made) | this repo |
| `icons/llm-brain.svg` | LLM (generates) | amber `#F5A623` | CC0 (self-made) | this repo |
| `icons/llm-brain-frozen.svg` | Frozen model (deterministic: NLI / embedding / token classifier) | blue `#6E9BD1` | CC0 (self-made) | this repo |
| `icons/doc-envelope.svg` | Query / prompt | tan+lilac | CC0 (self-made) | this repo |
| `icons/vector-db-cylinder.svg` | Vector database (generic) | tan `#C79A54` | CC0 (self-made) | this repo |
| `icons/code-tools.svg` | Tools & APIs | green `#7FB77E` | CC0 (self-made) | this repo |
| `icons/globe-internet.svg` | Internet / web search | blue `#6E9BD1` | CC0 (self-made) | this repo |
| `icons/doc-lines.svg` | Retrieved context / generic doc | lilac `#B9A7D6` | CC0 (self-made) | this repo |
| `icons/doc-lines-success.svg` | Final response / relevant | green `#7FB77E` | CC0 (self-made) | this repo |
| `icons/doc-lines-reject.svg` | Irrelevant / rejected | maroon `#B4685F` | CC0 (self-made) | this repo |
| `icons/step-badge.svg` | Numbered step badge (replace `N`) | cream+orange | CC0 (self-made) | this repo |
| `icons/person-expert.svg` | Human in the loop (domain expert / thesis author — node colour carries the role) | ink `#3A3A3A` + cream | CC0 (self-made) | this repo |
| `icons/doc-lock.svg` | Private / kept-out-of-repo artifact (e.g. pseudonymisation mapping) | maroon `#B4685F` + ink lock | CC0 (self-made) | this repo |

## Adding a new icon

1. Draw it in the house style (sketchy stroke, semantic colour — see the styleguide),
   **or** pull it from a CC0 / public-domain source only (see `../LICENSING.md`).
2. Strip/replace any vendor logo or trademark with a generic equivalent.
3. Save the SVG (and PNG if useful) here under the right subfolder.
4. Add a row to the manifest above with its role, colour, **License**, and **Source**.
