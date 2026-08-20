# Output — where does this page land?

`visualize` ships **one self-contained HTML** and shares it to a URL. That's the default
and the simplest. But "one HTML" still has to answer **where the reader is** — a doc
side-by-side, a 16:9 slide, a social card, a printed handout. The size, layout density,
and wording all change with the destination. Set the **output target** before you build;
it changes the canvas, the density, and the copy, so retrofitting afterwards means
rebuilding.

## The two dials

| Dial | Question | Default |
|------|----------|---------|
| **Target** | Where does this land — URL page, slide, README/docs, social, print? | `page` |
| **Density** | How much content per viewport — overview or detail? | `balanced` |

Infer the target from the request ("for my deck", "for the README", "a link to share").
If it's ambiguous, ask one concise question. If the user doesn't care, use `page` +
`balanced` and say so.

## 1. Target presets

| Target | When | Canvas / layout | Density | Deliverable |
|--------|------|-----------------|---------|-------------|
| **`page`** (default) | A shareable page in the browser | full-width responsive, `max-width` ~56–64rem | balanced | the URL |
| **`slide-16x9`** | A deck slide, projected | 1280×720-ish, dense but one-viewport | presentation | URL + optional PNG |
| **`slide-4x3`** | Legacy deck template | 1024×768-ish | presentation | URL |
| **`doc`** | README, docs site, blog embed | body-width (~960), compact | doc | URL or PNG |
| **`social-og`** | Link-preview / X / LinkedIn card | ~1200×630, one strong message | poster | PNG @2 |
| **`print`** | Handout, PDF deck, paper | A4/Letter landscape, high-contrast | print | PNG @3 |

**`page` is the default and almost always right** for `visualize`'s core job — a
shareable, scrollable, self-contained HTML. Reach for the others when the user names a
concrete destination (a slide, a README, a social post, a handout).

## 2. Density

| Density | What it means | When |
|---------|---------------|------|
| `overview` | Few nodes, big statements, scannable in one glance | social, slide titles, high-level map |
| `balanced` (default) | The normal card grid / tree / report | most page jobs |
| `detail` | More items, smaller type, annotations | reference, catalog, full tree |

Density is **not** a licence to cram — the pattern complexity budgets (patterns.md) still
apply. `detail` means more *relevant* items, not shrinking text to fit a kitchen sink.

## 3. How it changes the build

- **Canvas:** a `page` uses responsive inline CSS (`repeat(auto-fill, minmax(280px,1fr))`
  card grids, `max-width` main). A `slide` or `social` should fit **one viewport** — no
  scroll, fewer but bigger elements. A `doc` is body-width and compact.
- **Copy:** `overview`/`social` = one strong line, not prose. `detail`/`print` = room for
  annotations and a provenance footer.
- **Wording:** match the audience implied by the target — a slide for a stakeholder reads
  differently from a README for engineers, even for the same content.
- **Export:** `page` stays HTML + URL. For a slide/social/print you may also want a PNG —
  see below.

## 4. Getting a PNG (for slides, social, print)

`visualize`'s core is HTML + URL. When the target is a slide/social/print, a PNG is
usually the real deliverable. Two options:

```bash
# 1. Open the page and capture it (macOS: `screencapture`, or the browser's export)
visualize open out.html            # then export/screenshot a full-page PNG

# 2. Use rodney (headless Chrome in this repo) for a deterministic full-page PNG
rodney start
rodney open "file://$PWD/out.html" --screenshot out.png --full-page
rodney stop
```

For a **social-og** card, capture at 2× (e.g. 2400×1264) so it stays crisp on retina.
For **print**, capture at 3× for a clean A4/Letter raster.

> **Keep the HTML as source of truth.** Generate the HTML first; any PNG is derived from
> it. Don't hand-author a standalone image — the HTML is what you can edit and re-share.

## Rules

- **Target before build.** Set `page`/`slide`/`doc`/`social`/`print` before composing —
  it changes canvas, density, and copy.
- **`page` is the default.** Don't reach for a slide/social preset unless the user names a
  destination.
- **One viewport for slide/social.** No scroll; fewer, bigger elements; one strong message.
- **HTML is the source of truth.** PNG is derived, never the other way round.
- **Budgets still apply.** Density changes how much fits, not whether a pattern's budget
  can be blown.
