# Figure & asset licensing policy

**Goal:** every figure, image, and icon published in the thesis must be usable
**without requiring attribution** and without third-party permission.

This is a hard rule for anything under `figure/` that ends up in the thesis. Read it
before adding any asset.

## The one rule

> If you cannot show the asset is **self-made**, **CC0 / public domain**, or an
> **OFL-licensed font**, it does not go in the thesis.

Track the license of every asset in the manifest (`assets/README.md`). No license
recorded → treat as unpublishable.

## What is safe (attribution-free)

1. **Diagrams you draw yourself** (Excalidraw, tldraw, etc.). You own the copyright; no
   attribution needed. *This is the default and preferred path* — the whole styleguide
   exists so you can draw your own.
2. **The visual style itself.** A look/aesthetic is not copyrightable. Recreating the
   hand-drawn agentic-RAG *style* is fine; copying a *specific* third-party diagram is not.
3. **CC0 / Public Domain (CC-PD) assets.** Zero obligations. Cleanest possible source.
   - Icons: [SVG Repo](https://www.svgrepo.com) (filter **CC0 / Public Domain**),
     [unDraw](https://undraw.co) (MIT, no attribution required in practice),
     [Public Domain Vectors](https://publicdomainvectors.org).
4. **SIL Open Font License (OFL) fonts.** Can be embedded in a published PDF with **no
   attribution requirement** — the OFL only governs *redistributing the font files*, not
   documents that use the font. **The house font is `Patrick Hand` (OFL)**, vendored at
   `assets/fonts/PatrickHand-Regular.ttf` with its `OFL.txt`. It is the single font for all
   figures — no sans anywhere (see `styleguide/SKILL.md` §3).

## What is grey (avoid unless CC0 alternative is unavailable)

- **MIT / ISC / Apache-2.0 icon sets** (Lucide, Tabler, Heroicons, Feather). The license
  text technically must accompany redistributed *source*. For an icon rendered into a PDF
  this is widely treated as fine and needs no *visible* attribution — but CC0 or self-made
  is strictly safer, so prefer those. If you must use one, note the license in the manifest.

## What is banned (needs attribution / permission — do not publish)

- **The `styleguide/reference/*.jpeg` images.** Third-party copyright (Daily Dose of DS).
  **Style reference only — never place in the thesis.**
- **Company / product logos & trademarks:** Qdrant, DeepSeek, Linkup, Comet/Opik, OpenAI,
  Anthropic, AWS, etc. Even when trademark use is "nominative," it carries attribution and
  trademark baggage. Replace with **generic** icons:
  - Qdrant logo → generic **vector-database cylinder**
  - a specific model's logo → generic **LLM brain / chip** icon
  - a specific web tool's logo → generic **globe / browser-window** icon
- **CC-BY / CC-BY-SA** assets (require attribution by definition), and any
  **"free for personal use"** / non-commercial icon.
- Anything scraped from a paper, blog, or slide deck without a clear open license.

## Workflow

1. Draw it yourself in the house style whenever practical — that's automatically safe.
2. If you reuse an external icon, take it **only** from a CC0/public-domain source.
3. Strip/replace any vendor logo with a generic equivalent.
4. Record it in `assets/README.md` with its **License** and **Source** columns filled in.
5. Keep this file's rule in mind at export time (see the checklist in `styleguide/SKILL.md`).

## Font embedding note

When exporting the thesis PDF, **embed** the OFL font (standard in LaTeX/`fontspec` and in
most PDF exporters). Embedding an OFL font in a PDF is explicitly permitted and requires no
attribution. Do **not** ship the raw `.ttf/.otf` font file inside the repo's published
artifacts without its `OFL.txt` — but that constraint is about redistributing the *font*,
not the thesis.
