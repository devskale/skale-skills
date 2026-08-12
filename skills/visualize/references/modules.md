# Page modules — the visual building blocks

A page is **composed from modules**, not picked from full-page templates. Each module is a
self-contained HTML+CSS block with a clear job. Stack the modules that fit the request into
one self-contained page; every module shares the same house style, so any combination
composes cleanly.

## The shared base (every page starts with this)

```html
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport"
content="width=device-width, initial-scale=1"><title>{{TITLE}}</title><style>
:root{--accent:#10b981;--ink:#0f172a;--paper:#fafaf9;--muted:#71717a;--line:#e4e4e7}
*{box-sizing:border-box}
body{margin:0;font-family:system-ui,-apple-system,"Segoe UI",sans-serif;
     background:var(--paper);color:var(--ink);line-height:1.5}
main{max-width:72rem;margin:0 auto;padding:3rem 1.5rem 4rem}
</style></head><body><main>
  <!-- stacked modules here -->
</main></body></html>
```

One accent (`--accent`), warm paper, system-ui font. Every module below assumes this base.

---

## Module catalog

### header
Kicker + title + sub + optional meta. The top of every page.

```html
<header>
  <p class="kicker" style="font-size:.72rem;text-transform:uppercase;letter-spacing:.14em;color:var(--muted);margin:0 0 .3rem">{{KICKER}}</p>
  <h1 style="font-size:2rem;margin:0 0 .25rem;letter-spacing:-.02em">{{TITLE}}</h1>
  <p class="sub" style="color:var(--muted);margin:0;max-width:52rem">{{INTENT}}</p>
  <div class="meta" style="color:var(--muted);font-size:.85rem;margin-top:.5rem">{{AUTHOR}} · {{DATE}} · {{STATUS}}</div>
</header>
```

### legend
Color-coded category legend, under the header.

```html
<div class="legend" style="display:flex;gap:1.1rem;flex-wrap:wrap;margin-top:1.1rem;font-size:.78rem;color:var(--muted)">
  <span><span style="display:inline-block;width:.62rem;height:.62rem;border-radius:2px;margin-right:.3rem;vertical-align:middle;background:#0369a1"></span>{{CAT A}}</span>
  <span><span style="display:inline-block;width:.62rem;height:.62rem;border-radius:2px;margin-right:.3rem;vertical-align:middle;background:#b45309"></span>{{CAT B}}</span>
</div>
```

### card-grid
The workhorse for "a set of things." Responsive cards with a title and one line.
Category goes as **plain muted text** in the card footer — no colored pill badges (those
read as AI-generated).

```html
<div class="grid" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:1rem">
  <article style="background:#fff;border:1px solid var(--line);border-radius:.75rem;padding:1.25rem">
    <h3 style="font-size:1.05rem;margin:0 0 .4rem">{{TITLE}}</h3>
    <p style="color:var(--muted);font-size:.88rem;margin:0 0 .75rem">{{one-line}}</p>
    <div style="font-size:.75rem;color:var(--muted);letter-spacing:.02em">{{CATEGORY}}</div>
  </article>
</div>
```

### tree
Annotated repo/folder tree — indented rows + connector lines. The kind goes as **plain
muted text**, not a colored pill.

```html
<div style="font-size:.9rem">
  <div style="display:flex;align-items:baseline;gap:.6rem;padding:.16rem 0"><span style="width:1.1rem;text-align:center;flex:none;color:var(--muted)">📦</span><span style="font-weight:600">{{ROOT}}/</span><span style="color:var(--muted);font-size:.78rem;flex:1">{{one-line}}</span></div>
  <div style="border-left:1px solid var(--line);margin-left:.5rem;padding-left:1rem">
    <div style="display:flex;align-items:baseline;gap:.6rem;padding:.16rem 0"><span style="width:1.1rem;text-align:center;flex:none;color:var(--muted)">📁</span><span style="font-weight:600">{{DIR}}/</span><span style="color:var(--muted);font-size:.78rem;flex:1">{{summary}}</span></div>
    <div style="border-left:1px solid var(--line);margin-left:.5rem;padding-left:1rem">
      <div style="display:flex;align-items:baseline;gap:.6rem;padding:.16rem 0"><span style="width:1.1rem;text-align:center;flex:none;color:var(--muted)">🔍</span><span style="font-weight:600">{{item}}</span><span style="color:var(--muted);font-size:.78rem;flex:1">{{one-line}}</span><span style="font-size:.75rem;color:var(--muted)">{{KIND}}</span></div>
    </div>
  </div>
</div>
```

### flow
Horizontal pipeline steps (numbered).

```html
<div style="display:flex;align-items:stretch;gap:.4rem;flex-wrap:wrap">
  <div style="flex:1;min-width:120px;background:#fff;border:1px solid var(--line);border-radius:.6rem;padding:.7rem;text-align:center">
    <span style="display:inline-block;font-weight:650;color:var(--muted);margin-right:.3rem">1</span>
    <div style="font-weight:600;font-size:.85rem">{{STEP}}</div>
    <div style="color:var(--muted);font-size:.72rem;margin-top:.2rem">{{DETAIL}}</div>
  </div>
  <span style="align-self:center;color:var(--muted);font-size:1.1rem">→</span>
  <div style="flex:1;min-width:120px;background:#fff;border:1px solid var(--line);border-radius:.6rem;padding:.7rem;text-align:center">
    <span style="display:inline-block;font-weight:650;color:var(--muted);margin-right:.3rem">2</span>
    <div style="font-weight:600;font-size:.85rem">{{STEP}}</div>
    <div style="color:var(--muted);font-size:.72rem;margin-top:.2rem">{{DETAIL}}</div>
  </div>
</div>
```

### table
Data table (deploy matrix, comparisons).

```html
<table style="width:100%;border-collapse:collapse;font-size:.85rem;background:#fff;border:1px solid var(--line);border-radius:.6rem;overflow:hidden">
  <tr><th style="padding:.6rem .8rem;text-align:left;border-bottom:1px solid var(--line);background:var(--paper);text-transform:uppercase;font-size:.7rem;letter-spacing:.05em;color:var(--muted)">{{COL}}</th><th style="padding:.6rem .8rem;text-align:left;border-bottom:1px solid var(--line);background:var(--paper);text-transform:uppercase;font-size:.7rem;letter-spacing:.05em;color:var(--muted)">{{COL}}</th></tr>
  <tr><td style="padding:.6rem .8rem;border-bottom:1px solid var(--line)">{{VAL}}</td><td style="padding:.6rem .8rem;border-bottom:1px solid var(--line)">{{VAL}}</td></tr>
</table>
```

### section
Numbered section wrapper (for reports and multi-part pages).

```html
<section style="margin-top:2.5rem">
  <h2 style="font-size:1.2rem;margin:0 0 .75rem">
    <span style="font-weight:650;color:var(--muted);margin-right:.5rem">{{N}}</span>{{SECTION TITLE}}
  </h2>
  <p style="color:var(--ink)">{{content}}</p>
</section>
```

### exec-summary
Report findings box (left ink border).

```html
<section style="background:#fff;border:1px solid var(--line);border-left:3px solid var(--ink);border-radius:.4rem;padding:1.25rem 1.5rem;margin:1.5rem 0 2rem">
  <h2 style="margin-top:0;font-size:1.05rem">Executive summary</h2>
  <ul><li style="margin-bottom:.5rem"><strong>{{Finding}}</strong> — {{one line}}.</li></ul>
</section>
```

### recommendations
Prioritized recommendations.

```html
<ol>
  <li style="margin-bottom:.6rem"><strong>{{Do X}}</strong> — {{because Y}}. (priority: {{high}})</li>
</ol>
```

### mermaid
Graph-shaped content (flow, dependency, sequence). Uses Mermaid from CDN — **needs network**.

```html
<script src="https://cdn.tailwindcss.com"></script>
<script type="module">
  import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
  mermaid.initialize({ startOnLoad: true, theme: "neutral", securityLevel: "loose" });
</script>
<div style="background:#fff;border:1px solid var(--line);border-radius:.75rem;padding:1rem;margin:1rem 0">
  <pre class="mermaid">flowchart LR
    A[{{A}}] --> B[{{B}}]
    B --> C[{{C}}]</pre>
</div>
```

### footer
Provenance footer.

```html
<div style="margin-top:3rem;padding-top:1.25rem;border-top:1px solid var(--line);color:var(--muted);font-size:.82rem">
  Built with the <code>visualize</code> skill · shared via <code>lubu.skale.dev/throway</code> · expires ~4h
</div>
```

---

## Composing a page

1. **Pick the modules** that fit the request (from the catalog above).
2. **Stack them inside `<main>`** in reading order.
3. **Fill placeholders**, keep the shared base + house style.
4. **Validate** (`visualize validate`) → open → share.

A **report** = `header` + `exec-summary` + `section`(×N) + `recommendations` + `footer`.
A **visualization** = `header` + `legend` + `card-grid`/`tree`/`system-map` + `footer`.
Mix freely — a report can embed a `card-grid` or `mermaid` inside a `section`.

## Rules

- **Every module is self-contained** — its CSS is inline, so stacking never breaks layout.
- **Share the base + house style** — one muted ink + hairline `--line` + warm paper. Don't introduce a second palette.
- **No AI-generated accents.** Never use colored pill badges on cards, colored `.ok`/`.bad` cell values, colored numbered-circle badges on headings, or a saturated accent on links/buttons — they read as "LLM slop." Numbers as plain muted text, links as ink with a hairline underline, neutral table values.
- **Only include modules you use** — a simple page pulls 2–3, not a full template's unused CSS.
- **Mermaid needs network** — use the inline modules by default; reach for `mermaid` only for graph-shaped content.
