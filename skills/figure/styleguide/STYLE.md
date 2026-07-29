---
name: figure-styleguide
description: >
  Replicate the hand-drawn "Daily Dose of DS"-style architecture diagram look used for
  the thesis figures — sketchy Excalidraw-style nodes, pastel fills, dashed arrows,
  numbered step badges, and semantic colour coding. Use whenever you create, edit, or
  ask for a pipeline / workflow / architecture figure so every diagram in the thesis
  shares one visual language. Reference exemplars live in `reference/`; reusable icons
  and images live in `../assets/`.
---

# Figure Styleguide — hand-drawn agentic-RAG diagram look

This document defines the house style for architecture / workflow figures so they all
look like they were drawn by the same hand. It is modelled on the hand-drawn agentic-RAG
look (sketchy Excalidraw-style nodes, pastel fills, dashed arrows, numbered step badges).

**Golden rule:** every diagram is a *hand-drawn sketch*, not a corporate flowchart. When in
doubt, make it look like a neat Excalidraw whiteboard drawing.

**Licensing rule (non-negotiable):** everything published must be usable **without
attribution** — self-made, CC0/public-domain, or an OFL font. No vendor logos, no CC-BY.
Full policy: `../LICENSING.md`.

## 1. Tooling

Two routes, same look:

- **Programmatic compositor (preferred for consistency)** — `../build/`. Write a spec
  (nodes + edges + badges); it assembles the CC0 icons with the house palette, Patrick Hand,
  and standard boxes/arrows/badges into SVG **and** PNG. Same spec → identical figure every
  time, and a palette/badge change in the library re-styles *every* figure on rebuild. Use
  this for pipeline/architecture diagrams that must stay consistent across a set of figures.
  See `../build/README.md`.
- **Excalidraw (for one-off freehand sketches)** — excalidraw.com or the VS Code extension;
  gives the sketchy stroke, handwritten font, and wobbly boxes for free.

When hand-drawing in Excalidraw:

- Save the editable source as `*.excalidraw` (JSON) **and** export `*.svg` + `*.png`.
- Keep the `.excalidraw` source next to the export so figures stay editable.
- Alternatives that approximate the look: [tldraw], [Rough.js] for programmatic diagrams,
  or Mermaid with `look: handDrawn` + a custom theme (weakest match — falls back to this
  only for auto-generated diagrams).

## 2. Canvas & frame

- **Outer frame:** the whole diagram sits inside one large rounded rectangle with a thin
  soft-coloured border (light blue or light teal) on a near-white / very-light-tint fill.
- Generous padding inside the frame; let the diagram breathe.
- **Title** top-left or top-centre in the large handwritten font, plain ink on the
  canvas — **no background colour / highlighter swipe behind the title** (removed
  house-wide 2026-07-25).
- **No attribution / source / credit line inside the canvas** (no bottom-right
  "self-made, CC0" or similar). Licensing and provenance live in `../LICENSING.md`
  and the spec files, never in the image itself.

## 3. Typography

- **Font — one font, everywhere: `Patrick Hand`** (OFL; vendored at
  `../assets/fonts/PatrickHand-Regular.ttf`). Use it for **titles, node labels, edge
  labels, branch labels, and step badges alike**. Embeddable in the thesis PDF with no
  attribution.
- **No sans, ever.** The plain-sans node labels in the reference diagrams are the one thing
  we're *not* copying. Never use Arial/Helvetica/any straight sans in a figure — not even
  for small labels. In SVG/CSS the font stack must end in **`cursive`**, never
  `sans-serif`, so nothing silently falls back to a sans:
  `font-family: 'Patrick Hand', cursive;`
- Size/weight carry the hierarchy instead of switching fonts: title large, labels medium,
  edge/badge text small — all Patrick Hand.
- **Title:** large, bold, dark grey/near-black (not pure `#000`).
- **Node labels:** medium, dark grey, centred in the node.
- **Edge labels** (`Prompt`, `Validate`, `Merge context`, `web search if…`): small,
  placed beside the arrow, same handwritten font.
- **Branch labels:** `YES` in green, `NO` in red — short and uppercase.

## 4. Nodes (boxes)

- Rounded rectangles with a **sketchy / rough stroke** (Excalidraw "sloppiness: artist"),
  ~2px, and a **soft pastel fill** or white fill with a coloured border.
- A node = an icon (top) + a short label (bottom), or an icon beside text.
- Keep labels to 1–4 words; put questions on agent nodes (`Do I need more details?`,
  `Is the answer relevant?`).
- Don't overfill — one idea per box.

## 5. Arrows / edges

- **Dashed** arrows are the default connector (both references are almost entirely dashed).
- Thin, dark-grey stroke, simple open arrowhead, gentle right-angle or straight routing.
- Solid arrows are allowed sparingly for emphasis; prefer dashed for consistency.
- Label the *meaning* of a transition on the arrow when it isn't obvious.

## 6. Numbered step badges

The signature element: each transition carries a **numbered badge**.

- Small **circle**, cream/pale-yellow fill (`#FDF0D0`-ish), **dashed orange border**.
- Number centred, dark. Number them in execution order (1, 2, 3 …).
- **A badge must sit in clear whitespace on its line — never overlapping a box, another
  badge, or text, and never clipped.** In the reference the badges float in the gaps
  between nodes; match that. Centre the badge on the visible span of the arrow (the part
  between the two boxes), not at a spot that lands on a corner or under a node.
- Branch points get a badge plus a coloured `YES` / `NO` label.

**Layering & legibility rules (what keeps this from breaking):**
- **Badges and all edge labels render on top of everything** — draw them last, after the
  boxes, so a badge near a node is never hidden behind it.
- **Edge labels sit clear of the line and the badge:** offset them *perpendicular* to the
  arrow (not just a fixed nudge), enough to clear the ~15px badge, and put a soft
  paper-coloured **halo** behind the text so it stays readable where it crosses a line.
- Keep a badge and its edge label at *different* points on the arrow so they don't stack.

The `../build/` compositor enforces all of this automatically: badges snap to the nearest
clear whitespace on the path, labels get a perpendicular offset + halo, and both draw on
top of the nodes. If you hand-draw in Excalidraw, apply these rules yourself.

## 7. Colour & semantic coding

Colour is **meaningful**, not decorative — reuse the same colour for the same role across
every figure.

| Element / role            | Icon & colour                                              |
|---------------------------|------------------------------------------------------------|
| **LLM Agent** (decides)   | Red circuit-brain icon; red-outlined box                   |
| **LLM** (generates)       | Orange/amber circuit-brain icon                            |
| **Query / prompt doc**    | Envelope-with-document icon, cream/tan outline             |
| **Retrieved context**     | Lined-document icon, lilac/purple outline                  |
| **Vector database**       | Cylinder DB icon (Qdrant red accent), tan panel            |
| **Tools & APIs**          | `</>` code-in-circle icon                                  |
| **Internet / web search** | Globe / browser-window icon, blue outline                  |
| **Relevant / success**    | Green-outlined document                                    |
| **Irrelevant / reject**   | Red/maroon-outlined document                               |
| **Final response**        | Green filled box, lined-document icon                      |
| **Aggregated context**    | Purple/lilac stacked-document box                          |

Palette (pastel, low-saturation):

- Red `#E8443A` · Orange/amber `#F5A623` · Green `#7FB77E` / fill `#CDEAC0`
- Lilac/purple `#B9A7D6` · Blue `#8FB8DE` · Cream/tan `#F3E2C7` · badge fill `#FDF0D0`
- Frame border light blue `#AFC7E8` or light teal `#CDE3DD`; text dark grey `#3A3A3A`.

## 8. Layout & flow

- Left-to-right and/or top-to-bottom reading order; keep the numbered path traceable.
- Group the "data sources" (vector DB, tools, internet) into their own sub-panel/cluster.
- Align nodes on a loose grid — hand-drawn, not pixel-perfect, but not chaotic.
- Loops (e.g. "answer not relevant → back to start") route cleanly around the outside.

## 9. Reusing assets

- Pull icons/images from **`../assets/`** — don't redraw an icon that already exists.
  - `../assets/icons/` — the reusable icon set (LLM-agent brain, DB cylinder, envelope
    doc, globe, `</>`, etc.). See `../assets/README.md` for the manifest.
  - `../assets/images/` — larger reusable illustrations / logos.
- When you make a new icon in the house style, **save it back** into `../assets/icons/`
  (SVG preferred) and add a row to the manifest so the next figure can reuse it.

## 10. Checklist before exporting

- [ ] Sketchy stroke + handwritten font throughout
- [ ] Rounded frame with soft border, plain title (no background swipe)
- [ ] Dashed arrows with clear direction
- [ ] Numbered cream/orange-dashed badges in execution order
- [ ] Colours follow the semantic table (agent = red, LLM = orange, success = green …)
- [ ] Icons reused from `../assets/`; any new icon saved back + logged
- [ ] **Publishable:** every element self-made / CC0 / OFL — no vendor logos, no CC-BY (`../LICENSING.md`)
- [ ] Patrick Hand only — no sans anywhere; font stack ends in `cursive`
- [ ] OFL font embedded on export
- [ ] Exported to SVG **and** a matching PNG (for phone/preview); `.excalidraw` source kept
      alongside. For `assets/` SVGs, `node figure/assets/render_pngs.mjs` makes the PNGs.

[tldraw]: https://www.tldraw.com
[Rough.js]: https://roughjs.com
