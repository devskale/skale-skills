# Prompt library — great visualizations

A cookbook of prompts/patterns that reliably produce *lovely* self-contained HTML
visualizations. These are the moves that separate a "fine" page from one the user
says *"that's lovely."* Read this when building; don't read it to decide what to build.

> **How to use:** this is a library, not a script. Pick the moves that fit the subject
> and intent. The single strongest predictor of a lovely page is **real, specific
> content** + one clear visual structure — everything else is polish on top.

---

## 0. The foundation: real content, one structure

Before any styling, nail these two:

- **Use the actual subject.** If the user asks to visualize "the repo," read the repo and
  surface *real* items with *real* one-line descriptions. Never invent or pad. A page of
  genuine specifics beats a page of generic placeholders every time.
- **Pick ONE structure** (from structures.md) and commit to it. Don't blend cards + grid +
  timeline + flow on one page unless the content is genuinely two-sided.

Everything below is polish that makes that foundation sing.

---

## 1. Establish a visual identity (the "house style")

Set up a small palette and stick to it. This is what makes the page feel *designed* rather
than *default*.

```css
:root {
  --accent: #10b981;          /* ONE accent — emerald, indigo, or similar */
  --ink:    #0f172a;          /* near-black text */
  --paper:  #fafaf9;          /* warm off-white background */
  --muted:  #71717a;          /* secondary text */
  --line:   #e4e4e7;          /* hairline borders */
}
```

Rules:
- **One accent colour** used sparingly (headings, key highlights, a tint). Everything else
  in neutrals. Two accents = noise.
- **Warm paper background** (`#fafaf9` stone-50) reads more editorial than pure white.
- **System-ui font stack** — zero font downloads, looks native everywhere:
  `font-family: system-ui, -apple-system, "Segoe UI", sans-serif;`

---

## 2. Group with colour, not with borders

The single highest-impact move for "a set of things." When items fall into categories,
**colour-code the categories** and show a legend.

- Give each category a distinct badge colour (see the palette below).
- Add a compact **legend** under the header so the colours read instantly.
- Keep category colours *muted pastels* — loud saturated fills scream dashboard.

```css
.badge { display:inline-block; font-size:.7rem; text-transform:uppercase;
         letter-spacing:.05em; padding:.18rem .55rem; border-radius:999px; font-weight:600; }
.badge.web     { background:#e0f2fe; color:#0369a1; }   /* sky   */
.badge.browser { background:#fef3c7; color:#b45309; }   /* amber */
.badge.media   { background:#fce7f3; color:#be185d; }   /* pink  */
.badge.diagram { background:#e0e7ff; color:#4338ca; }   /* indigo*/
.badge.proto   { background:#dcfce7; color:#15803d; }   /* green */
```

Legend (in the header):

```html
<div class="legend">
  <span><span class="dot" style="background:#0369a1"></span>Web</span>
  <span><span class="dot" style="background:#b45309"></span>Browser</span>
  ...
</div>
```

---

## 3. The card grid — the workhorse for "a set of things"

Cards with a title, one muted line, and a badge. This is the default for heterogeneous
sets and reads beautifully.

```css
.grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); gap:1rem; }
.card { background:#fff; border:1px solid var(--line); border-radius:.75rem;
        padding:1.25rem; transition:transform .12s ease, box-shadow .12s ease; }
.card:hover { transform:translateY(-2px); box-shadow:0 6px 18px rgba(15,23,42,.08); }
.card h3 { font-size:1.05rem; margin:0 0 .4rem; }
.card p  { color:var(--muted); font-size:.88rem; margin:0 0 .9rem; }
```

`repeat(auto-fill, minmax(280px, 1fr))` is the magic line — it wraps responsively with no
media queries.

---

## 4. Header & scannable hierarchy

- **Big title** (`~2rem`, tight letter-spacing `-.02em`), then a **one-line sub** in muted
  that states the intent.
- **Section headers** in `uppercase, letter-spacing .08em` — they read as wayfinding, not
  content.
- **Sparse prose everywhere.** If a sentence could be a bullet, make it a bullet. If a
  bullet could be cut, cut it. The *visuals* carry the meaning.

---

## 5. Provenance footer (the "lovely" finishing touch)

End with a quiet footer that says how the page was made. It's a small human touch that
makes the page feel intentional and trustworthy.

```html
<div class="footer">
  Built with the <code>visualize</code> skill · one self-contained HTML file ·
  shared via <code>lubu.skale.dev/throway</code> · expires ~4h
</div>
```

```css
.footer { margin-top:3rem; padding-top:1.5rem; border-top:1px solid var(--line);
          color:var(--muted); font-size:.82rem; }
.footer code { background:#fff; border:1px solid var(--line); border-radius:.35rem;
               padding:.1rem .4rem; font-size:.8rem; }
```

---

## 6. Anti-patterns (what kills a visualization)

- **Generic dashboard** — dense tables of numbers, heavy chrome, saturated corporate
  colours. Editorial, not enterprise.
- **Kitchen sink** — every structure on one page. One strong structure wins.
- **Prose walls** — paragraphs where bullets/visuals belong.
- **Invented content** — placeholder names, fake stats, "Item 1" cards. Use the real thing.
- **No hierarchy** — everything the same size/weight. Titles, sections, cards, muted text:
  each level visibly different.
- **External deps for the core** — the layout must work from inline CSS alone. (Optional
  Mermaid for complex graphs is fine; the page itself must not depend on it.)
- **Colored pill badges on every card** — the tell-tale AI-generated look. Small rounded
  `border-radius:999px` capsules with pastel backgrounds and uppercase text scream "LLM
  slop." **Never use them.** Categories go as plain muted text in the card footer, or as a
  quiet legend — not a colored pill on each item.

---

## 6.5 Design principles (grounded in research)

These come from Edward Tufte's data-visualization principles — the gold standard used by
the FT, The Economist, Bloomberg, McKinsey. They make a report/visualization *trustworthy*,
not just pretty.

**1. Maximise the data-ink ratio.** `Data-Ink / Total Ink`. Every drop of ink should
represent data. Erase non-data-ink (borders, backgrounds, unnecessary gridlines) and
redundant duplicates. → In our pages: hairline `--line` borders, warm paper, no heavy
chrome. Don't add decorative boxes/borders that carry no information.

**2. Show data in comparison.** An isolated number is meaningless — the question is always
"compared to what?" Juxtaposition creates meaning. → In our pages: use `table`,
`before-after`, or side-by-side cards to put values in context, never a lone figure.

**3. No chartjunk.** Decorative elements that add no information undermine authority —
they signal the data alone isn't compelling. → In our pages: every visual element must
earn its place. No gratuitous gradients, shadows, or icons that don't communicate.

**4. Reveal mechanism, not just outcome.** Great graphics show *why*, not just *what*.
Minard's map of Napoleon's campaign reveals the cause (winter), not just the loss. → In
our pages: when showing a result, show the flow/process that produced it (`flow` module,
a `mermaid` graph, a pipeline).

**5. Show relevant complexity.** Oversimplifying misleads. Show how variables interact
when that interaction is the point. → In our pages: use `system-map` or multivariate
`table`s when the relationships matter, not a reductive single view.

**6. Guard the lie factor.** The graphic must accurately reflect the data — no distorted
scales, truncated axes, or area-as-one-dimensional tricks. → In our pages: keep charts
honest; don't exaggerate differences to make a point.

> **Apply these through the module system.** The modules are designed to embody these
> principles (hairlines, comparison, mechanism via flow/mermaid, honest scales). When
> composing, ask: *is every element earning its ink? is this shown in comparison? does it
> reveal the mechanism?* If not, cut or rework it.

---

## 7. Quick recipe — "a set of things" (the repo card grid)

The exact recipe that produced the skale-skills overview:

1. **Subject:** read the repo; list the real skills/extensions with one-line descriptions.
2. **Structure:** `overview-grid` of `cards`.
3. **Identity:** emerald accent, stone paper, system-ui.
4. **Grouping:** colour-coded badges (web/browser/media/diagram/proto/ext) + header legend.
5. **Hierarchy:** big title → one-line sub → section headers → cards → muted prose.
6. **Provenance footer** with the visualize/throway note.
7. **Validate:** `visualize validate <file>` (self-contained) → `open` → `share`.

---

## 8. Quick recipe — the annotated repo tree

For "show me what's in this repo / show the tree" — don't dump a bare `tree`/`find`
output. **Annotate it** so each node tells you what it *is*. This is the move that makes
it lovely.

1. **Get the real tree:** `find . -maxdepth 2 -not -path './.git/*' ...` (prune venvs,
   node_modules, caches) — but treat it as a *skeleton*, not the deliverable.
2. **Structure:** `hierarchy` — nested indented rows with connector lines, not boxes.
3. **Annotate every node:** name + one-line muted description + a colour-coded tag.
4. **Colour-code by kind:** skill / extension / prompt / core / docs / test — with a
   legend (reuse the badge palette from §2).
5. **Icons per node** (📁 dir, 📄 file, plus a per-kind emoji) for quick scanning.
6. **Collapse deep dirs** — show the top ~2 levels richly, and summarise deeper ones
   (e.g. `deprecated/ → retired skills`) rather than listing every file.
7. **Provenance footer** + validate → open → share.

### Tree CSS (the essentials)

```css
.row{display:flex;align-items:baseline;gap:.6rem;padding:.18rem 0;border-radius:.35rem}
.row:hover{background:#fff}
.name{font-weight:600}
.name.dir{color:var(--ink)}
.desc{color:var(--muted);font-size:.8rem;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.tag{flex:none;font-size:.68rem;text-transform:uppercase;letter-spacing:.04em;padding:.12rem .45rem;border-radius:999px;font-weight:600}
.connector{border-left:1px solid var(--line);margin-left:.5rem;padding-left:1rem}
```

Nest children in a `.connector` div (a left hairline + indent) under the parent row.
The `.desc` uses `flex:1` + ellipsis so annotations truncate gracefully on narrow screens.

### Anti-patterns specific to trees

- **Bare `tree` dump** — raw file listing with no meaning. Always annotate.
- **Collapse-everything JS** — collapse is a nice-to-have; the page must render
  statically. Use indentation, not `<details>`/JS, for the default view.
- **Infinite depth** — don't render 8 levels of node_modules. Summarise deep dirs.

---

## 9. Quick recipe — the system map (multi-repo / multi-service platform)

For an **orchestrator/metarepo/platform** — a repo that coordinates sub-repos, a fleet of
servers, and a pipeline. A flat tree undersells it; build a **multi-panel system map**.
This is the recipe that produced the kontext.one map.

**First — understand the platform.** Read the README, the central config (e.g. `repos.yml`,
`package.json` scripts), and the sub-repos. Ask: is this a normal codebase, or an
orchestrator whose *relationships* are the point? If the latter, use a system map.

Then pick the panels that fit (not all always apply):

1. **Repo topology** — a metarepo box containing its sub-repos; each sub-repo gets a card
   with role tag (frontend/backend/lib/data) + deploy target.
2. **Pipeline / data flow** — the end-to-end flow as numbered horizontal steps.
3. **Fleet** — the servers/machines as a grid, each with role + what runs there.
4. **Tree (top level)** — the orchestration skeleton (CLI, central config, sub-repos,
   docs, tests).

### Key CSS

**Metarepo box + sub-repo cards:**

```css
.meta{background:#fff;border:1px solid var(--line);border-radius:.9rem;padding:1.4rem}
.subgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:.9rem}
.subrepo{background:var(--paper);border:1px solid var(--line);border-radius:.6rem;padding:.9rem}
.subrepo .sr-name{font-weight:600;display:flex;justify-content:space-between;align-items:center}
.subrepo .sr-desc{color:var(--muted);font-size:.8rem;margin:.3rem 0 .6rem}
.sr-meta{font-size:.72rem;color:var(--muted)}
.sr-meta span{background:#fff;border:1px solid var(--line);border-radius:999px;padding:.1rem .45rem}
```

**Horizontal flow steps:**

```css
.flow{display:flex;align-items:stretch;gap:.4rem;flex-wrap:wrap}
.step{flex:1;min-width:130px;background:#fff;border:1px solid var(--line);border-radius:.6rem;padding:.7rem;text-align:center}
.step .st-n{display:inline-block;background:var(--accent);color:#fff;width:1.2rem;height:1.2rem;border-radius:50%;font-size:.7rem;line-height:1.2rem}
.arrow{align-self:center;color:var(--muted);font-size:1.1rem}
```

**Server cards:** a grid of `.server` cards (name, role, meta) — same shape as `.subrepo`.

### Numbered panels

Give each panel a numbered heading badge (`.panel h2 .n`) so the page reads as a guided
tour: 1 Repo topology → 2 Pipeline → 3 Fleet → 4 Tree.

### Anti-patterns specific to system maps

- **Flat tree for an orchestrator** — a metarepo's *relationships* are the point; a tree
  hides them. Use a system map.
- **Every panel on every repo** — only include panels that fit. A simple 2-repo setup
  doesn't need a 4-panel map.
- **Static data** — the flow/fleet/topology must reflect the real `repos.yml`/config, not
  invented servers or stages.

---

## 10. When to recommend d2 / figure (don't force an inline diagram)

`visualize` builds simple diagrams inline (SVG arrows, Mermaid) — fine for a small graph
embedded in a page. But some challenges are **better handed to `d2` or `figure`**, and you
should **recommend them** (you can't auto-invoke them — they're manual-only).

**Recommend `d2`** for complex technical graphs: sequence / ER / class diagrams,
dependency or call graphs with many nodes, anything that needs auto-layout + self-
verification, or a diagram that is *the deliverable* (`.svg`/`.png`/`.pdf` to commit).

**Recommend `figure`** for hand-drawn, presentation-quality explainers — sketchy pipeline /
workflow / architecture figures for a slide or report.

**Build inline** only when the diagram is simple (a few nodes) and *one element among
many* in a quick shareable page. Don't bounce the user to d2/figure for a trivial graph.

**How to recommend:** one line at the end of the page, e.g. *"This graph is complex — for
a proper auto-laid-out diagram run `/skill:d2`; for a hand-drawn figure `/skill:figure`."*
Don't over-recommend.
