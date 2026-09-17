# Page modules — the visual building blocks

A page is **composed from modules**, not picked from full-page templates. All CSS lives
**once in the shared base** below — a module is just a **short class-based HTML block**.
Copy the base, stack the modules that fit, fill the placeholders. Instantiating a card is
4 lines of HTML, not 300 characters of inline style re-rolled per element.

## The shared base (copy once — every page starts with this)

```html
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport"
content="width=device-width, initial-scale=1"><title>{{TITLE}}</title><style>
:root{--ink:#1a1a1a;--paper:#fafaf9;--paper-2:#f4f4f5;--muted:#6b7280;--soft:#a1a1aa;--line:#e5e5e5;
      --accent:#10b981;--cat-1:#5e7a9b;--cat-2:#7c8f6f;--cat-3:#b8915a;
      --ok:#15803d;--warn:#b45309;--bad:#b91c1c}
*{box-sizing:border-box}
body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;
     background:var(--paper);color:var(--ink);line-height:1.5}
main{max-width:72rem;margin:0 auto;padding:3rem 1.5rem 4rem}
header{margin-bottom:2.5rem}
.kicker{font-size:.72rem;text-transform:uppercase;letter-spacing:.14em;color:var(--muted);margin:0 0 .3rem}
h1{font-size:2rem;margin:0 0 .25rem;letter-spacing:-.02em;font-weight:650}
.sub{color:var(--muted);margin:0;max-width:52rem}
.meta{color:var(--muted);font-size:.85rem;margin-top:.5rem}
.legend{display:flex;gap:1.1rem;flex-wrap:wrap;margin-top:1.1rem;font-size:.78rem;color:var(--muted)}
.dot{display:inline-block;width:.62rem;height:.62rem;border-radius:2px;margin-right:.3rem;vertical-align:middle}
.section{margin-top:2.75rem}
.section>h2{font-size:.95rem;margin:0 0 1rem;text-transform:uppercase;letter-spacing:.1em;color:var(--muted)}
section h2 .n{font-weight:650;color:var(--cat-1);margin-right:.5rem}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:1rem}
.grid+.grid{margin-top:1.75rem}
.card{background:#fff;border:1px solid var(--line);border-radius:.75rem;padding:1.25rem}
.card h3{font-size:1.05rem;margin:0 0 .4rem;font-weight:600}
.card p{color:var(--muted);font-size:.88rem;margin:0 0 .75rem}
.card .cat{font-size:.75rem;color:var(--muted);letter-spacing:.02em}
.tree{font-size:.9rem}
.row{display:flex;align-items:baseline;gap:.6rem;padding:.16rem 0}
.row .ic{width:1.1rem;text-align:center;flex:none;color:var(--muted)}
.row .name{font-weight:500}
.row .name.dir{font-weight:700}
.row .desc{color:var(--muted);font-size:.78rem;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.row .kind{font-size:.75rem;color:var(--muted)}
.connector{border-left:1px solid var(--line);margin-left:.5rem;padding-left:1rem}
.flow{display:flex;align-items:stretch;gap:.4rem;flex-wrap:wrap}
.step{flex:1;min-width:120px;background:#fff;border:1px solid var(--line);border-radius:.6rem;padding:.7rem;text-align:center}
.step .n{display:inline-block;font-weight:650;color:var(--muted);margin-right:.3rem}
.step .name{font-weight:600;font-size:.85rem}
.step .note{color:var(--muted);font-size:.72rem;margin-top:.2rem}
.arrow{align-self:center;color:var(--muted);font-size:1.1rem}
table{width:100%;border-collapse:collapse;font-size:.85rem;background:#fff;border:1px solid var(--line);border-radius:.6rem;overflow:hidden}
th{padding:.6rem .8rem;text-align:left;border-bottom:1px solid var(--line);background:var(--paper);text-transform:uppercase;font-size:.7rem;letter-spacing:.05em;color:var(--muted)}
td{padding:.6rem .8rem;border-bottom:1px solid var(--line)}
.exec-summary{background:#fff;border:1px solid var(--line);border-radius:.5rem;padding:1.25rem 1.5rem;margin:1.5rem 0 2rem}
.exec-summary h2{margin-top:0;font-size:1.05rem}
.exec-summary ul{margin:.5rem 0 0;padding-left:1.2rem}
.exec-summary li{margin-bottom:.5rem}
.sev{font-weight:600;font-size:.85em}
.sev.ok{color:var(--ok)}.sev.warn{color:var(--warn)}.sev.bad{color:var(--bad)}
ol.recs li{margin-bottom:.6rem}
.mermaid-card{background:#fff;border:1px solid var(--line);border-radius:.75rem;padding:1rem;margin:1rem 0}
.footer{margin-top:3rem;padding-top:1.25rem;border-top:1px solid var(--line);color:var(--muted);font-size:.82rem}
.footer code{background:#fff;border:1px solid var(--line);border-radius:.3rem;padding:.1rem .4rem;font-size:.8rem}
</style></head><body><main>
  <!-- stacked modules here -->
</main></body></html>
```

Neutral ink on warm paper, system-ui font. Every class used below is defined here.
**Colour is structure, not decoration:** category hues (`--cat-1..3`) sit on small
elements — dots, swatches, 2px rules, small kickers; severity `--ok/--warn/--bad` only
when the colour IS the data (findings, priorities, test results). Never decorative:
pastel pill capsules, saturated link text, large numbered circles (~20px+), colour that
encodes nothing.

---

## Module catalog

### header
Kicker + title + sub + optional meta. The top of every page.

```html
<header>
  <p class="kicker">{{KICKER}}</p>
  <h1>{{TITLE}}</h1>
  <p class="sub">{{INTENT}}</p>
  <div class="meta">{{AUTHOR}} · {{DATE}} · {{STATUS}}</div>
</header>
```

### legend
Color-coded category legend, under the header. One hue per category, reused on the
cards/rows themselves.

```html
<div class="legend">
  <span><span class="dot" style="background:var(--cat-1)"></span>{{CAT A}}</span>
  <span><span class="dot" style="background:var(--cat-2)"></span>{{CAT B}}</span>
  <span><span class="dot" style="background:var(--cat-3)"></span>{{CAT C}}</span>
</div>
```

### card-grid
The workhorse for "a set of things." Responsive cards with a title and one line.
Category = **small dot in the category hue + plain muted text** in the footer — the dot
reuses the legend hue for that category (`var(--cat-N)`); never colored pill badges
(those read as AI-generated).

```html
<div class="grid">
  <article class="card">
    <h3>{{TITLE}}</h3>
    <p>{{one-line}}</p>
    <div class="cat"><span class="dot" style="background:var(--cat-1)"></span>{{CATEGORY}}</div>
  </article>
  <!-- one article.card per item — the dot reuses the legend hue for that category -->
</div>
```

### tree
Annotated repo/folder tree — indented rows + connector lines. The kind goes as a
**dot in its category hue + plain muted text** (same hue as its legend entry), never a
colored pill. Nest deeper levels inside `.connector` divs.

```html
<div class="tree">
  <div class="row"><span class="ic">📦</span><span class="name dir">{{ROOT}}/</span><span class="desc">{{one-line}}</span></div>
  <div class="connector">
    <div class="row"><span class="ic">📁</span><span class="name dir">{{DIR}}/</span><span class="desc">{{summary}}</span></div>
    <div class="connector">
      <div class="row"><span class="ic">🔍</span><span class="name">{{item}}</span><span class="desc">{{one-line}}</span><span class="kind"><span class="dot" style="background:var(--cat-1)"></span>{{KIND}}</span></div>
    </div>
  </div>
</div>
```

### flow
Horizontal pipeline steps (numbered).

```html
<div class="flow">
  <div class="step"><span class="n">1</span><div class="name">{{STEP}}</div><div class="note">{{DETAIL}}</div></div>
  <span class="arrow">→</span>
  <div class="step"><span class="n">2</span><div class="name">{{STEP}}</div><div class="note">{{DETAIL}}</div></div>
</div>
```

### table
Data table (deploy matrix, comparisons).

```html
<table>
  <tr><th>{{COL}}</th><th>{{COL}}</th></tr>
  <tr><td>{{VAL}}</td><td>{{VAL}}</td></tr>
</table>
```

### section
Numbered section wrapper (for reports and multi-part pages).

```html
<section class="section">
  <h2><span class="n">{{N}}</span>{{SECTION TITLE}}</h2>
  <p>{{content}}</p>
</section>
```

### exec-summary
Report findings box (plain bordered card). Findings carry a **severity** — colored value
text is structural here (the color IS the data). `.sev` words are free (`critical`,
`healthy`, …); classes are `ok` / `warn` / `bad`.

```html
<section class="exec-summary">
  <h2>Executive summary</h2>
  <ul>
    <li><strong>{{Finding}}</strong> — {{one line}}. <span class="sev bad">{{critical}}</span></li>
    <li><strong>{{Finding}}</strong> — {{one line}}. <span class="sev ok">{{healthy}}</span></li>
  </ul>
</section>
```

### recommendations
Prioritized recommendations. Priority gets its severity hue via `.sev` (`bad` high,
`warn` medium, `ok` low).

```html
<ol class="recs">
  <li><strong>{{Do X}}</strong> — {{because Y}}. (priority: <span class="sev bad">high</span>)</li>
  <li><strong>{{Do Z}}</strong> — {{because W}}. (priority: <span class="sev warn">medium</span>)</li>
</ol>
```

### mermaid
Graph-shaped content (flow, dependency, sequence). Uses Mermaid from CDN — **needs network**.
Keep page layout in the base CSS (house tokens); Mermaid only renders the diagram block.

```html
<script type="module">
  import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@12/dist/mermaid.esm.min.mjs";
  mermaid.initialize({ startOnLoad: true, theme: "neutral", securityLevel: "loose" });
</script>
<div class="mermaid-card">
  <pre class="mermaid">flowchart LR
    A[{{A}}] --> B[{{B}}]
    B --> C[{{C}}]</pre>
</div>
```

### footer
Provenance footer.

```html
<div class="footer">
  Built with the <code>visualize</code> skill · shared via <code>lubu.skale.dev/throway</code> · expires ~4h
</div>
```

---

## Composing a page

1. **Copy the shared base** into the output file — all module CSS is already in it
   (unused rules cost ~2KB; harmless).
2. **Stack module blocks inside `<main>`** in reading order.
3. **Fill placeholders** with real content — never ship `{{...}}`.
4. **Validate** (`visualize validate`) → lint → open → share.

A **report** = `header` + `exec-summary` + `section`(×N) + `recommendations` + `footer`.
A **visualization** = `header` + `legend` + `card-grid`/`tree`/`flow` + `footer`.
Mix freely — a report can embed a `card-grid` or `mermaid` inside a `section`.

## Rules

- **Classes from the shared base** — write short class-based HTML; never re-declare or
  inline-duplicate module CSS per element. That duplication is the hand-rolled page:
  verbose to emit, inconsistent to edit, bloated to ship.
- **Share the house style** — one muted ink + hairline `--line` + warm paper, plus the
  structural tokens (`--cat-*`, `--ok/--warn/--bad`). Don't introduce a second palette.
- **Colour is structure, not decoration.** Category hues on small elements (dots,
  swatches, kickers, 2px rules); severity hues only when the colour IS the data. Never
  use pastel pill capsules on cards, saturated accent on links/buttons, or large colored
  numbered-circle badges (~20px+) — they read as "LLM slop." Links stay ink with a
  hairline underline.
- **Borders mark real boundaries** — common region is the strongest grouping cue; it
  overrides proximity. Don't box every line ("card soup") — when proximity alone groups
  cleanly, skip the border.
- **A connector line is a relationship claim** — never draw one you don't mean; a stray
  line implies a phantom relationship.
- **A template beats composing** when one fits exactly (`templates/`) — same style,
  pre-assembled.
- **Mermaid needs network** — use the inline modules by default; reach for `mermaid`
  only for graph-shaped content.
