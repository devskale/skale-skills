// web-search skill — automatic backend selection.
// Two backends, but several variants subsume into them:
//   SearXNG: public (default, zero-config) OR private (credgoo `searx`) — all result types.
//   Duck API: needs token (credgoo WEB_SEARCH_BEARER); carries the advanced filters
//            (site/filetype/inurl/exclude/exact).
// Routing (select_backend): --api→Duck · --searxng→SearXNG · token+text→Duck ·
//   token+media→SearXNG · no-token→SearXNG. Collapses to: Duck iff (--api or token+text);
//   else SearXNG. Media (images/news/videos) always routes to SearXNG.
//
// Badge logic: the DEFAULT path (public SearXNG, no creds) carries the numbered spine
// (1→2→3); Duck is an unnumbered branch. credgoo feeds BOTH: bearer→Duck (required),
// searx→SearXNG-private (optional, dashed).
//
// Lint:  node build/review_figure.mjs diagrams/examples/web-search/web-search.fig.mjs
// Build: cd skills/figure && node build/build_figures.mjs diagrams/examples/web-search/web-search.fig.mjs

export default {
  name: 'web-search',
  title: 'web-search skill',
  width: 1320,
  height: 700,

  nodes: [
    // ── entry ──
    { id: 'call',     x: 40,   y: 330, w: 180, h: 130, icon: 'doc-envelope',      color: 'tan',
      label: "web-search\n\"query\" + opts", labelSize: 16 },

    // ── the decision (brain) ──
    { id: 'select',   x: 280,  y: 330, w: 200, h: 130, icon: 'llm-agent-brain',   agent: true,
      label: 'select backend\nby flags · token · type', labelSize: 15 },

    // ── default backend: works zero-config, or private via credgoo ──
    { id: 'searxng',  x: 600,  y: 90,  w: 250, h: 170, icon: 'globe-internet',   color: 'green',
      label: 'SearXNG\npublic (default)\n· or private: credgoo searx\ntext · images · news · videos', labelSize: 15 },

    // ── upgrade backend: token + advanced filters ──
    { id: 'duck',     x: 600,  y: 440, w: 250, h: 170, icon: 'globe-internet',   color: 'blue',
      label: 'Duck API\ntoken required\nsite · filetype · inurl\nexclude · exact', labelSize: 15 },

    // ── credential store (feeds both) ──
    { id: 'credgoo',  x: 280,  y: 540, w: 200, h: 110, icon: 'doc-lock',         color: 'tan',
      label: 'credgoo\nsearx · WEB_SEARCH_BEARER', labelSize: 15 },

    // ── output ──
    { id: 'results',  x: 960,  y: 330, w: 220, h: 150, icon: 'doc-lines-success', color: 'green',
      label: 'results\ntext · images\nnews · videos', labelSize: 16 },
  ],

  edges: [
    // ── spine: request ──
    { from: 'call',    to: 'select',  badge: 1 },

    // default routing (numbered spine) — no token, or media, or --searxng
    { from: 'select',  to: 'searxng', badge: 2, label: 'default · media', labelT: 0.22,
      path: [[480, 360], [540, 360], [540, 175], [600, 175]] },

    // upgrade branch (unnumbered) — token + text, or --api
    { from: 'select',  to: 'duck',    label: 'if token', labelT: 0.22,
      path: [[480, 430], [540, 430], [540, 525], [600, 525]] },

    // credgoo feeds Duck (required token)
    { from: 'credgoo', to: 'duck',    label: 'bearer',
      path: [[480, 580], [540, 580], [540, 555], [600, 555]] },

    // credgoo feeds SearXNG-private (optional — dashed)
    { from: 'credgoo', to: 'searxng', dashed: true, label: 'searx (private)',
      path: [[380, 540], [380, 250], [560, 250], [560, 200], [600, 200]] },

    // ── spine: results (numbered on the default path) ──
    { from: 'searxng', to: 'results', badge: 3,
      path: [[850, 175], [910, 175], [910, 370], [960, 370]] },

    // alternative path to the same results (unnumbered)
    { from: 'duck',    to: 'results', label: 'ok',
      path: [[850, 525], [910, 525], [910, 440], [960, 440]] },
  ],
};
