// fetch-url skill — auto-selects the best backend with smart fallback.
// Priority: free local tools (w3m, lynx) -> free APIs (jina, markdown) -> chrome (headless).
// On failure, falls through to the next tool in the chain.
//
// Layout logic:
//  - The three tools stack vertically (w3m → jina → chrome = priority order).
//  - Fallback = a SHORT VERTICAL DROP to the tool directly below (jina is below w3m,
//    chrome below jina). "NO" markers sit on these drops, in the tool column (x≈635).
//  - Success ("ok") goes RIGHT to fetch.
//  - The select→w3m success path is the ONLY thing in the left channel (x≈480) — so
//    "try" + badge 2 never share a region with the "NO" markers (~155px apart).
//
// Badge logic: badges trace the SPINE only (1 request → 2 try → 3 return). The three
// tool→fetch edges are MUTUALLY EXCLUSIVE alternatives, not sequential steps, so they are
// NOT numbered — "ok" / "NO" carry the conditional.
//
// Collision-avoidance verified with build/detect_label_collisions.mjs.
// Build:  cd skills/figure && node build/build_figures.mjs diagrams/examples/fetch-url/fetch-url.fig.mjs

export default {
  name: 'fetch-url',
  title: 'fetch-url skill',
  width: 1280,
  height: 660,

  nodes: [
    // ── entry ──
    { id: 'call',    x: 40,   y: 295, icon: 'doc-envelope',       color: 'tan',
      label: 'fetch-url "URL"\nuser call', labelSize: 16 },

    // ── select best tool (the brain) ──
    { id: 'select',  x: 250,  y: 295, icon: 'llm-agent-brain',   agent: true,
      label: 'auto-select\nbest tool\n(site hints + priority)', labelSize: 15 },

    // ── tool chain: priority order, top to bottom, stacked so fallback = drop down ──
    { id: 'w3m',     x: 560,  y: 50,  icon: 'code-tools',         color: 'green',
      label: 'w3m / lynx\nfree · local', labelSize: 15 },
    { id: 'jina',    x: 560,  y: 255, icon: 'code-tools',         color: 'blue',
      label: 'jina / markdown\nfree API', labelSize: 15 },
    { id: 'chrome',  x: 560,  y: 460, icon: 'code-tools',         color: 'amber',
      label: 'chrome\nheadless · JS sites', labelSize: 15 },

    // ── fetch + extract ──
    { id: 'fetch',   x: 850,  y: 295, icon: 'globe-internet',    color: 'blue',
      label: 'fetch URL\nextract text', labelSize: 16 },

    // ── output ──
    { id: 'out',     x: 1090, y: 295, icon: 'doc-lines-success', color: 'green',
      label: 'clean text\nto caller', labelSize: 16 },
  ],

  edges: [
    // ── spine (numbered): request → try → return ──
    { from: 'call',   to: 'select', badge: 1 },

    // select → w3m: the ONLY edge in the left channel. "try" + badge 2 live here alone.
    { from: 'select', to: 'w3m',    badge: 2, label: 'try', labelT: 0.2,
      path: [[400, 325], [480, 325], [480, 125], [560, 125]] },

    // ── success: each tool → fetch (RIGHT). "ok" = success. Unnumbered alternatives. ──
    { from: 'w3m',    to: 'fetch',  label: 'ok',
      path: [[710, 125], [780, 125], [780, 265], [850, 265]] },
    { from: 'jina',   to: 'fetch',  label: 'ok',
      path: [[710, 330], [850, 330]] },
    { from: 'chrome', to: 'fetch',  label: 'ok',
      path: [[710, 535], [780, 535], [780, 355], [850, 355]] },

    // ── fallback: SHORT VERTICAL DROP to the tool directly below. "NO" = fail → next.
    //    Sits in the tool column (x≈635), far from the left-channel "try"/badge 2.
    { from: 'w3m',   to: 'jina',   branch: 'no', fromSide: 'bottom', toSide: 'top' },
    { from: 'jina',  to: 'chrome', branch: 'no', fromSide: 'bottom', toSide: 'top' },

    // ── spine (numbered): return ──
    { from: 'fetch', to: 'out',    badge: 3, label: 'return' },
  ],
};
