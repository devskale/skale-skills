# Report mode — structured documents

A **report** is a *document* — a structured narrative with findings, sections, and
recommendations — as opposed to a *visualization*, which is a display of a set of things.
A report often embeds visualizations (charts, maps, diagrams) inside its sections.

Use **report mode** when the deliverable is a document: "write me a report on X",
"evaluate Y", "summarise the audit", "assess these options", "findings + recommendations".

## Anatomy of a report

A good report in one self-contained HTML file:

1. **Title + metadata** — title, subtitle/intent, author/date, status (draft/final).
2. **Executive summary** — the top 3–5 findings/recommendations up front, before the
   detail. The reader should get the gist without scrolling.
3. **Sections** — each a coherent unit with a heading, findings, and supporting visuals.
   Numbered for navigation.
4. **Recommendations / conclusion** — what to do next, prioritised.
5. **Appendix** (optional) — tables, raw data, method notes, references.

## Report structure (HTML scaffold)

Use semantic sections with a table of contents / nav when the report is long enough to
warrant it.

```html
<main class="report">
  <header>
    <p class="kicker">REPORT</p>
    <h1>Title</h1>
    <p class="sub">Subtitle / intent</p>
    <div class="meta">Author · Date · Status</div>
  </header>

  <section class="exec-summary">
    <h2>Executive summary</h2>
    <ul class="findings">
      <li><strong>Finding 1</strong> — one line.</li>
      <li><strong>Finding 2</strong> — one line.</li>
    </ul>
  </section>

  <section id="s1">
    <h2><span class="n">1</span> Section title</h2>
    <p>...prose...</p>
    <!-- embed a visual: inline SVG, a card grid, a chart -->
  </section>

  <section id="recs">
    <h2>Recommendations</h2>
    <ol class="recs">
      <li><strong>Do X</strong> — because Y. (priority: high)</li>
    </ol>
  </section>
</main>
```

## Report CSS essentials

```css
.report{max-width:56rem;margin:0 auto;padding:3rem 1.5rem 4rem}
.kicker{font-size:.75rem;text-transform:uppercase;letter-spacing:.12em;color:var(--accent);margin:0 0 .3rem}
.meta{color:var(--muted);font-size:.85rem;margin-top:.5rem}
.exec-summary{background:#fff;border:1px solid var(--line);border-left:4px solid var(--accent);border-radius:.6rem;padding:1.25rem 1.5rem;margin:1.5rem 0 2rem}
.exec-summary h2{margin-top:0}
.findings li{margin-bottom:.5rem}
section h2{font-size:1.2rem;display:flex;align-items:center;gap:.5rem;margin:2.5rem 0 .75rem}
section h2 .n{background:var(--accent);color:#fff;width:1.4rem;height:1.4rem;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;font-size:.8rem}
.recs li{margin-bottom:.6rem}
```

## Tone & content

- **Findings first.** State the finding, then the evidence. Don't bury the conclusion.
- **Prioritise recommendations.** Order by impact/urgency; tag with a priority if useful.
- **Sparse prose, rich visuals.** A report is still a `visualize` deliverable — embed
  card grids, before/after, charts, or a system map where they communicate better than
  text.
- **Be specific, not generic.** Use the real subject's data and findings. No filler like
  "it's worth noting that…".
- **Executive summary is non-negotiable.** Even a short report should open with the key
  points.

## Report vs. visualization

| | Report | Visualization |
|---|---|---|
| Deliverable | a document | a display |
| Core | narrative, findings, recommendations | a set of things, a structure |
| Sections | yes, numbered | usually not |
| Exec summary | yes | no |
| Embeds visuals | yes | is the visual |

When in doubt: if the user says "report / evaluate / summarise / assess / findings",
build a **report**. If they say "show / map / compare / visualize / page", build a
**visualization**. A report can embed a visualization; the reverse is unusual.
