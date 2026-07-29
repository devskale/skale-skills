// figure — the figure skill, drawn by itself.
// Depicts the post-deepening architecture: a spec flows into layout(), which resolves a
// pure-data model that TWO consumers read — composeSVG (model -> SVG) and review_figure
// (model -> bounds/collisions). One model, two adapters over the seam.
//
// Badge logic: the numbered spine traces resolution (1 spec in -> 2 resolve model). The
// two consumer edges are unnumbered (they read the SAME model concurrently, not in
// sequence) — mirroring how fetch-url left parallel alternatives unnumbered.
// Lint:  node build/review_figure.mjs diagrams/examples/figure/figure.fig.mjs

export default {
  name: 'figure',
  title: 'figure skill — itself',
  width: 1280,
  height: 560,

  nodes: [
    // ── input ──
    { id: 'spec',    x: 40,   y: 250, w: 170, h: 130, icon: 'doc-lines',         color: 'tan',
      label: 'spec\n.fig.mjs', labelSize: 16 },

    // ── the deep module (brain): resolves geometry ──
    { id: 'layout',  x: 270,  y: 250, w: 190, h: 130, icon: 'llm-agent-brain',   agent: true,
      label: 'layout(spec)', labelSize: 17 },

    // ── the resolved model (pure data) ──
    { id: 'model',   x: 540,  y: 250, w: 200, h: 130, icon: 'doc-lines',         color: 'lilac',
      label: 'resolved\nmodel', labelSize: 16 },

    // ── consumer 1: emit ──
    { id: 'compose', x: 840,  y: 110, w: 190, h: 120, icon: 'code-tools',        color: 'green',
      label: 'composeSVG\nmodel -> SVG', labelSize: 15 },

    // ── consumer 2: check ──
    { id: 'review',  x: 840,  y: 350, w: 190, h: 120, icon: 'code-tools',        color: 'blue',
      label: 'review_figure\nbounds + collisions', labelSize: 15 },

    // ── outputs ──
    { id: 'svg',     x: 1100, y: 110, w: 150, h: 110, icon: 'doc-lines-success', color: 'green',
      label: 'SVG', labelSize: 16 },
    { id: 'lint',    x: 1100, y: 350, w: 160, h: 110, icon: 'doc-lines-success', color: 'green',
      label: 'clean / fix', labelSize: 16 },
  ],

  edges: [
    // numbered spine: resolution
    { from: 'spec',   to: 'layout', badge: 1 },
    { from: 'layout', to: 'model',  badge: 2, label: 'resolve' },

    // the seam: the SAME model feeds both consumers (concurrent, not sequential -> unnumbered)
    { from: 'model',  to: 'compose', label: 'model',
      path: [[740, 300], [790, 300], [790, 170], [840, 170]] },
    { from: 'model',  to: 'review',  label: 'model',
      path: [[740, 330], [790, 330], [790, 410], [840, 410]] },

    { from: 'compose', to: 'svg',  label: 'emit' },
    { from: 'review',  to: 'lint', label: 'check' },
  ],
};
