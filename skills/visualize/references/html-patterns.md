# HTML patterns — one self-contained file

Everything inline. The file must render as a standalone document with **no external
network dependency for the core layout**. Inline CSS does all the layout and styling;
only *optional* diagram enhancement may use a CDN (and should degrade gracefully).

## Minimal scaffold

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Visualization — {{subject}}</title>
    <style>
      :root { --accent: #10b981; --ink: #0f172a; --paper: #fafaf9; --muted: #71717a; --line: #e4e4e7; }
      * { box-sizing: border-box; }
      body { margin: 0; font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
             background: var(--paper); color: var(--ink); line-height: 1.5; }
      main { max-width: 72rem; margin: 0 auto; padding: 3rem 1.5rem; }
      h1 { font-size: 1.75rem; margin: 0 0 .25rem; }
      .sub { color: var(--muted); margin-bottom: 2.5rem; }
      .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1rem; }
      .card { background: #fff; border: 1px solid var(--line); border-radius: .75rem; padding: 1.25rem; }
      .card h2 { font-size: 1.05rem; margin: 0 0 .5rem; }
      .card p { color: var(--muted); font-size: .9rem; margin: 0 0 .75rem; }
      .badge { display: inline-block; font-size: .72rem; text-transform: uppercase; letter-spacing: .05em;
               padding: .2rem .55rem; border-radius: 999px; background: color-mix(in srgb, var(--accent) 15%, transparent); color: var(--accent); }
      .muted { color: var(--muted); }
    </style>
  </head>
  <body>
    <main>
      <h1>{{title}}</h1>
      <p class="sub">{{one-line intent}}</p>
      <div class="grid">
        <article class="card">
          <h2>{{item title}}</h2>
          <p>{{item body}}</p>
          <span class="badge">{{tag}}</span>
        </article>
      </div>
    </main>
  </body>
</html>
```

## Inline CSS toolkit (no framework needed)

Use CSS variables for a consistent palette; one accent colour plus a muted neutral.
`color-mix()` keeps badge/tint variants without extra colours. System-ui font stack means
zero font downloads.

- **Cards / tiles**: `.card` above.
- **Two-column before/after**: `display:grid; grid-template-columns:1fr 1fr; gap:1.5rem;`
- **Timeline**: a left border on a container + `.dot` markers per entry.
- **Hierarchy**: nested `<ul>` with border-left connectors, or nested boxes.
- **Flow**: boxes as `<div>`s; arrows as inline `<svg>` (see below).

## Inline SVG arrows (flow / before-after)

Hand-drawn arrows beat a library for small, stable diagrams. Position an SVG absolutely
over a relative container, or just place small inline SVGs between boxes:

```html
<svg width="40" height="16" viewBox="0 0 40 16" fill="none">
  <path d="M0 8 H32 M32 8 L26 3 M32 8 L26 13" stroke="var(--ink)" stroke-width="1.5"/>
</svg>
```

## Mermaid (optional — only for complex graphs)

Use Mermaid only when the graph is genuinely complex (many nodes/edges) and hand-drawn
SVG would be unwieldy. It loads from a CDN at runtime, so it **needs network**. Keep the
page layout in inline CSS; Mermaid only renders the diagram block. Wrap it in a card so it
doesn't feel parachuted in.

```html
<script type="module">
  import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
  mermaid.initialize({ startOnLoad: true, theme: "neutral", securityLevel: "loose" });
</script>
<div style="background:#fff;border:1px solid var(--line);border-radius:.75rem;padding:1rem;margin:1rem 0;">
  <pre class="mermaid">
    flowchart LR
      A[Input] --> B[Process]
      B --> C[Output]
  </pre>
</div>
```

## Style guidance

- **Editorial, not dashboard** — generous whitespace, one accent, clear hierarchy.
- **Sparse prose** — the visuals carry the meaning. Bullets over paragraphs.
- **Diagrams ~320px tall** so side-by-side fits without scrolling.
- **`text-transform: uppercase; letter-spacing`** for labels — schematic, not UI.
- Keep the only scripts to Mermaid (if used). Otherwise the page is static.

## Self-containment checklist

Before delivering, run `visualize validate <file.html>`. It flags any external
`src`/`href` that isn't the Tailwind CDN. The rule: the page must render its content and
layout with the file alone — no stylesheet, no script, no image, no font fetched from
elsewhere.
