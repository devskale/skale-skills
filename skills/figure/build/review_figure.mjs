#!/usr/bin/env node
// review_figure.mjs — a figure reviewer: catches geometry issues in a spec.
//
// PURE MODEL-CHECKER. Calls layout(spec) and checks the RESOLVED MODEL.
// No SVG read, no Playwright, no renderer — runs pre-render, fully dep-free.
//
// Two severities:
//   ERROR   — bad edge endpoint (from/to not a node). Fatal: layout() would crash /
//             compose would dangle the edge. Fails the build.
//   WARNING — out-of-bounds (node box or text rect past the frame), text-rect collisions,
//             node-box overlaps (with tolerance), aspect-ratio bloat. Non-blocking: the
//             figure still renders; the agent reads these and iterates.
//
// Positions + dims come from layout()'s ONE model, so review checks the EXACT rects compose
// draws. Exits 1 on any ERROR, 0 on warnings-only.
//
// Usage:  node review_figure.mjs path/to/figure.fig.mjs
//         Or import { reviewSpec } and consume the structured result (build_figures.mjs does
//         this to run the lint always-on after each build).

import { pathToFileURL } from 'node:url';
import { argv, exit } from 'node:process';
import { layout } from './layout.mjs';

const FRAME = 6;          // frame inset (matches the drawn frame)
const BLOAT_RATIO = 2.2;  // width:height above which a figure renders compressed
const OVERLAP_TOL = 8;    // px shrunk from each node box before overlap is flagged (touching ≠ overlap)

// Review a spec → { issues: [{type, severity, id, detail, fix}], width, height }.
// errors abort; warnings are informational. Bad endpoints short-circuit (layout() would crash).
export function reviewSpec(spec) {
  const issues = [];
  const width = spec.width ?? 1200;
  const height = spec.height ?? 800;
  const nodes = spec.nodes ?? [];
  const nodeById = Object.fromEntries(nodes.map((n) => [n.id, n]));
  const nodeIds = new Set(nodes.map((n) => n.id));

  // ── ERRORS: bad edge endpoints (from/to not a declared node) ──
  for (const e of spec.edges ?? []) {
    if (e.from != null && !nodeIds.has(e.from))
      issues.push({ type: 'BAD-EDGE', severity: 'error', id: `edge from "${e.from}"`,
        detail: `"from": "${e.from}" is not a node id in spec.nodes`, fix: 'fix the edge "from", or add the node' });
    if (e.to != null && !nodeIds.has(e.to))
      issues.push({ type: 'BAD-EDGE', severity: 'error', id: `edge to "${e.to}"`,
        detail: `"to": "${e.to}" is not a node id in spec.nodes`, fix: 'fix the edge "to", or add the node' });
  }
  if (issues.some((i) => i.severity === 'error')) return { issues, width, height };

  // Safe to resolve geometry — no dangling endpoints.
  const model = layout(spec);
  const { width: W, height: H } = model;
  const safe = { left: FRAME, right: W - FRAME, top: FRAME, bottom: H - FRAME };

  // ── WARNINGS: aspect-ratio bloat ──
  if (W / H > BLOAT_RATIO)
    issues.push({ type: 'BLOAT', severity: 'warning', id: `aspect ${W}:${H}`,
      detail: `width:height ratio ${(W / H).toFixed(2)} > ${BLOAT_RATIO} — figure renders compressed in a normal viewport`,
      fix: 'trim labels, drop side branches, or raise the height' });

  // ── text rects (title, node labels, edge labels, badges, branches) ──
  const rects = [];
  if (model.title) rects.push({ kind: 'title', text: model.title.text, pos: model.title.pos, halfW: model.title.halfW, halfH: model.title.halfH, source: 'title' });
  for (const [id, b] of Object.entries(model.boxes)) {
    if (b.label) rects.push({ kind: 'node-label', text: b.label.text, pos: b.label.pos, halfW: b.label.halfW, halfH: b.label.halfH, source: `node "${id}"` });
  }
  for (const me of model.edges) {
    const src = `edge ${me.from}→${me.to}`;
    if (me.label) rects.push({ kind: 'label', text: me.label.text, pos: me.label.pos, halfW: me.label.halfW, halfH: me.label.halfH, source: src });
    if (me.badge != null) rects.push({ kind: 'badge', text: String(me.badge.n), pos: me.badge.pos, halfW: me.badge.halfW, halfH: me.badge.halfH, source: src });
    if (me.branch) rects.push({ kind: 'branch', text: me.branch.text, pos: me.branch.pos, halfW: me.branch.halfW, halfH: me.branch.halfH, source: src });
  }
  const bounds = (r) => ({ l: r.pos[0] - r.halfW, r: r.pos[0] + r.halfW, t: r.pos[1] - r.halfH, b: r.pos[1] + r.halfH });

  // ── WARNINGS: node-box out of bounds ──
  for (const [id, b] of Object.entries(model.boxes)) {
    if (nodeById[id]?.plain) continue;
    const br = b.x + b.w, bb = b.y + b.h;
    if (b.x < safe.left || br > safe.right || b.y < safe.top || bb > safe.bottom) {
      const over = [];
      if (b.x < safe.left) over.push(`left ${Math.ceil(safe.left - b.x)}px over`);
      if (br > safe.right) over.push(`right ${Math.ceil(br - safe.right)}px over`);
      if (b.y < safe.top) over.push(`top ${Math.ceil(safe.top - b.y)}px over`);
      if (bb > safe.bottom) over.push(`bottom ${Math.ceil(bb - safe.bottom)}px over`);
      const fix = [];
      if (bb > safe.bottom) fix.push(`move "${id}" up by ${Math.ceil(bb - safe.bottom)}px or raise height to ${H + Math.ceil(bb - safe.bottom)}`);
      if (br > safe.right) fix.push(`move "${id}" left by ${Math.ceil(br - safe.right)}px or widen to ${W + Math.ceil(br - safe.right)}`);
      if (b.x < safe.left) fix.push(`move "${id}" right by ${Math.ceil(safe.left - b.x)}px`);
      if (b.y < safe.top) fix.push(`move "${id}" down by ${Math.ceil(safe.top - b.y)}px`);
      issues.push({ type: 'OOB', severity: 'warning', id: `node "${id}"`,
        detail: `box [${b.x},${b.y} ${b.w}×${b.h}]; ${over.join(', ')}`, fix: fix.join('; ') });
    }
  }

  // ── WARNINGS: text rect out of bounds ──
  for (const r of rects) {
    const b = bounds(r);
    if (b.l < safe.left || b.r > safe.right || b.t < safe.top || b.b > safe.bottom)
      issues.push({ type: 'OOB', severity: 'warning', id: `${r.kind} "${r.text}"`,
        detail: `at (${r.pos[0].toFixed(0)},${r.pos[1].toFixed(0)}) exceeds frame [${safe.left}..${safe.right}]×[${safe.top}..${safe.bottom}]`,
        fix: `move/route so "${r.text}" sits inside the frame` });
  }

  // ── WARNINGS: node-box overlap (tolerance; touching is fine) ──
  const boxList = Object.entries(model.boxes).filter(([id]) => !nodeById[id]?.plain);
  for (let i = 0; i < boxList.length; i++) {
    for (let j = i + 1; j < boxList.length; j++) {
      const [idA, a] = boxList[i], [idB, b] = boxList[j];
      const ix = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x) - 2 * OVERLAP_TOL;
      const iy = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y) - 2 * OVERLAP_TOL;
      if (ix > 0 && iy > 0)
        issues.push({ type: 'OVERLAP', severity: 'warning', id: `nodes "${idA}" ↔ "${idB}"`,
          detail: `boxes overlap ~${(ix * iy).toFixed(0)}px² (after ${OVERLAP_TOL}px tolerance)`,
          fix: 'move one node so its box clears the other' });
    }
  }

  // ── WARNINGS: text-rect collisions (pairwise) ──
  const overlap = (a, b) => {
    const ix = Math.max(0, Math.min(a.r, b.r) - Math.max(a.l, b.l));
    const iy = Math.max(0, Math.min(a.b, b.b) - Math.max(a.t, b.t));
    return ix * iy;
  };
  for (let i = 0; i < rects.length; i++) {
    for (let j = i + 1; j < rects.length; j++) {
      const ov = overlap(bounds(rects[i]), bounds(rects[j]));
      if (ov > 0)
        issues.push({ type: 'COLLISION', severity: 'warning', id: `"${rects[i].text}" ↔ "${rects[j].text}"`,
          detail: `${rects[i].source} ↔ ${rects[j].source}; overlap ${ov.toFixed(0)}px²`,
          fix: 'shorten a label, route to a clear channel, or offset with labelT' });
    }
  }

  return { issues, width: W, height: H };
}

export function formatReport(name, { issues, width, height }) {
  if (!issues.length) return `✓ ${name}: all nodes & labels inside frame; no collisions. (canvas ${width}×${height})`;
  const errs = issues.filter((i) => i.severity === 'error');
  const warns = issues.filter((i) => i.severity === 'warning');
  const head = `${name}: ${errs.length} error(s), ${warns.length} warning(s)  (canvas ${width}×${height})`;
  const lines = issues.map((i) => `[${i.type}/${i.severity}] ${i.id}\n   ${i.detail}\n   → fix: ${i.fix}`);
  return head + '\n' + lines.join('\n');
}

// ── CLI (only when run directly; build_figures.mjs imports reviewSpec instead) ──
const isMain = process.argv[1] && /review_figure\.mjs$/.test(process.argv[1]);
if (isMain) {
  const specPath = argv[2];
  if (!specPath) { console.error('usage: node review_figure.mjs <figure.fig.mjs>'); exit(1); }
  const spec = (await import(pathToFileURL(specPath).href)).default;
  const result = reviewSpec(spec);
  console.log(formatReport(spec.name ?? specPath, result));
  exit(result.issues.some((i) => i.severity === 'error') ? 1 : 0);
}
