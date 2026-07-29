// Thesis scope map — what the thesis is GIVEN, what it BUILDS (C1–C3), what it
// DELIVERS. Flow only (author calls 2026-07-11/12): the worked-on-not-claimed,
// out-of-scope and still-open lists live in scope.md, not in the figure.
// Layout (2026-07-12 rework, pass 2): one horizontal SPINE on a single
// centerline (FFG data -> author gold -> anonymise -> C2 -> C1 -> code
// release); the harness->scorer gap is widened so the runs-label sits INSIDE
// the gap; every label hugs its own edge; models sit directly beneath the
// harness (author call 2026-07-23), feeding it straight up; the THESIS box is
// the largest node — the semantic terminal — with RQ1/RQ2 and RQ3 arriving on
// short separated runs. No crossings, no outside loop.
// The fixed proposal contract box was dropped 2026-07-12 (author call) — it
// stays documented in scope.md.
// Anchors: thesis/supervisor_presentation/scope.md · thesis/outline.md (framing)
//          proposal/ (fixed RQ contract) · AGENTS.md open/next.
// Build:  NODE_PATH=/opt/node22/lib/node_modules node figure/build/build_figures.mjs figure/diagrams/scope/scope-map/scope-map.fig.mjs

export default {
  name: 'scope-map',
  title: 'Thesis Scope',
  width: 2010,
  height: 760,

  nodes: [
    // ---- zone headers (text only) ----
    { id: 'hGiven', x: 150, y: 88, w: 550, h: 24, plain: true, labelSize: 20,
      label: 'GIVEN INPUTS' },
    { id: 'hTh',    x: 885, y: 88, w: 550, h: 24, plain: true, labelSize: 20,
      label: 'THE THESIS — contributions C1–C3' },
    { id: 'hOut',   x: 1740, y: 88, w: 220, h: 24, plain: true, labelSize: 20,
      label: 'OUTPUTS' },

    // ---- top lane: raw docs ----
    { id: 'corpus', x: 50, y: 120, w: 180, h: 130, icon: 'doc-lines', color: 'lilac',
      label: 'Real tender + bid docs\n3 tenders · 5 bidders', labelSize: 14 },

    // ---- the spine (one centerline, left to right) ----
    { id: 'ffgdata', x: 50, y: 320, w: 180, h: 150, icon: 'doc-lock', color: 'tan',
      label: 'FFG data\n(given)', labelSize: 15 },
    { id: 'authorgold', x: 330, y: 320, w: 180, h: 150, icon: 'llm-brain', color: 'amber',
      label: 'Author gold', labelSize: 15 },
    { id: 'anon', x: 610, y: 320, w: 190, h: 150, icon: 'code-tools', color: 'green',
      label: 'Anonymise first\n(before experiments)', labelSize: 15 },
    { id: 'harness', x: 900, y: 320, w: 210, h: 150, icon: 'llm-agent-brain', agent: true,
      label: 'C2 — harness\nP0 · P1 ReAct · P2 ReWOO', labelSize: 15 },
    { id: 'scorer', x: 1270, y: 320, w: 210, h: 150, icon: 'code-tools', color: 'green',
      label: 'C1 — metric suite\nM1–M7 · M8 · M9–M12', labelSize: 15 },
    { id: 'code', x: 1740, y: 320, w: 200, h: 150, icon: 'code-tools', color: 'green',
      label: 'Code released\nharness + scorer', labelSize: 15 },

    // ---- under lane: sources / infra / validation / the thesis itself ----
    { id: 'audits', x: 50, y: 540, w: 180, h: 150, icon: 'person-expert', color: 'blue',
      label: 'Historical AI audits\n+ expert ratings', labelSize: 15 },
    // directly beneath the harness it feeds (straight vertical, author call)
    { id: 'models', x: 900, y: 540, w: 210, h: 150, icon: 'llm-brain-frozen', color: 'blue',
      label: 'Frozen API models\n(TU gateway)', labelSize: 15 },
    { id: 'valid', x: 1270, y: 540, w: 210, h: 150, icon: 'person-expert', color: 'blue',
      label: 'C3 — expert validation\npreregistered · German', labelSize: 14 },
    // the semantic terminal — largest node on the sheet
    { id: 'thesis', x: 1740, y: 530, w: 220, h: 170, icon: 'doc-lines-success', color: 'green',
      label: 'Thesis — RQ1–3\nanswered', labelSize: 16 },
  ],

  edges: [
    // the given material funnels into the FFG data package: docs from above,
    // the historical tool runs / expert Stage ratings from below — both are
    // source material only (never a system under test); shared feed -> badge 1
    { from: 'corpus', to: 'ffgdata', badge: 1, fromSide: 'bottom', toSide: 'top' },
    { from: 'audits', to: 'ffgdata', badge: 1, fromSide: 'top', toSide: 'bottom' },

    // the spine: author gold over the FFG data, anonymise (one substitution
    // over sources and gold, spans re-verified), then the experiments
    { from: 'ffgdata',    to: 'authorgold', badge: 2 },
    { from: 'authorgold', to: 'anon',       badge: 3 },
    { from: 'anon',       to: 'harness',    badge: 4 },
    // frozen models are consumed together with the anonymised data (shared badge 4)
    { from: 'models', to: 'harness', badge: 4, fromSide: 'top', toSide: 'bottom' },

    // the runs: every arm answers every instance, repeated for stability
    { from: 'harness', to: 'scorer', badge: 5 },

    // scoring feeds the validation subset
    { from: 'scorer', to: 'valid', badge: 6, fromSide: 'bottom', toSide: 'top' },

    // results into the thesis: RQ1/RQ2 from C1, RQ3 from C3 — short separated runs
    { from: 'scorer', to: 'thesis', badge: 7, badgeT: 0.8,
      label: 'RQ1 · RQ2',
      path: [[1480, 435], [1740, 565]] },
    { from: 'valid', to: 'thesis', badge: 8, badgeT: 0.8,
      label: 'RQ3' },

    // deliverable beyond the document (code decided in scope; data release open):
    // the code release continues the spine row
    { from: 'scorer', to: 'code', badge: 9, label: 'code, not data (yet)' },
  ],
};
