#!/usr/bin/env node
// review_figure.mjs — a figure reviewer: catches out-of-bounds elements + label collisions.
//
// PURE MODEL-CHECKER. Imports the spec, calls layout(spec), and checks the RESOLVED MODEL.
// No SVG read, no Playwright, no renderer — runs pre-render, fully dep-free. (The SVG file
// need not exist; this lints the spec itself.)
//
// Two failure classes:
//   1. OUT OF BOUNDS — a node box or text rect that pokes outside the frame
//      (the frame is drawn at a 6px inset, so the safe area is [6, W-6] × [6, H-6]).
//   2. COLLISIONS — two text rects (title, node labels, edge labels, badges, branches)
//      whose bboxes overlap.
//
// Positions + dims come from layout()'s ONE model, so review checks the EXACT rects compose
// draws — no char-width heuristic, no SVG regex. The old multi-line-label false-positive
// class is gone by construction (a node label is one rect). Any collision review flags is a
// real halo overlap the eye already has.
//
// Usage:  node review_figure.mjs path/to/figure.fig.mjs
//         Exits 0 if clean, 1 on issues. Slots into a refine loop: build → review → fix.

import { pathToFileURL } from 'node:url';
import { argv, exit } from 'node:process';
import { layout } from './layout.mjs';

const specPath = argv[2];
if (!specPath) { console.error('usage: node review_figure.mjs <figure.fig.mjs>'); exit(1); }
const spec = (await import(pathToFileURL(specPath).href)).default;
const model = layout(spec);
const { width: W, height: H } = model;

const FRAME = 6;
const safe = { left: FRAME, right: W - FRAME, top: FRAME, bottom: H - FRAME };

// ── build the flat list of text rects review checks ──
// each: { kind, text, pos:[x,y], halfW, halfH, source }
const rects = [];
const nodeById = Object.fromEntries((spec.nodes ?? []).map((n) => [n.id, n]));

if (model.title) {
  rects.push({ kind: 'title', text: model.title.text, pos: model.title.pos,
    halfW: model.title.halfW, halfH: model.title.halfH, source: 'title' });
}
for (const [id, b] of Object.entries(model.boxes)) {
  if (b.label) {
    rects.push({ kind: 'node-label', text: b.label.text, pos: b.label.pos,
      halfW: b.label.halfW, halfH: b.label.halfH, source: `node "${id}"` });
  }
}
for (const me of model.edges) {
  const src = `edge ${me.from}→${me.to}`;
  if (me.label) rects.push({ kind: 'label', text: me.label.text, pos: me.label.pos, halfW: me.label.halfW, halfH: me.label.halfH, source: src });
  if (me.badge != null) rects.push({ kind: 'badge', text: String(me.badge.n), pos: me.badge.pos, halfW: me.badge.halfW, halfH: me.badge.halfH, source: src });
  if (me.branch) rects.push({ kind: 'branch', text: me.branch.text, pos: me.branch.pos, halfW: me.branch.halfW, halfH: me.branch.halfH, source: src });
}

const bounds = (r) => ({ l: r.pos[0] - r.halfW, r: r.pos[0] + r.halfW, t: r.pos[1] - r.halfH, b: r.pos[1] + r.halfH });
const issues = [];

// 1. NODE BOX BOUNDS (plain nodes have no box to bound)
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
    if (bb > safe.bottom) fix.push(`move "${id}" up by ${Math.ceil(bb - safe.bottom)}px (y ${b.y}→${b.y - Math.ceil(bb - safe.bottom)}) or raise height to ${H + Math.ceil(bb - safe.bottom)}`);
    if (br > safe.right) fix.push(`move "${id}" left by ${Math.ceil(br - safe.right)}px or widen to ${W + Math.ceil(br - safe.right)}`);
    if (b.x < safe.left) fix.push(`move "${id}" right by ${Math.ceil(safe.left - b.x)}px`);
    if (b.y < safe.top) fix.push(`move "${id}" down by ${Math.ceil(safe.top - b.y)}px`);
    issues.push({ type: 'OOB', id: `node "${id}"`, detail: `box [${b.x},${b.y} ${b.w}×${b.h}] bottom=${bb} right=${br}; ${over.join(', ')}`, fix: fix.join('; ') });
  }
}

// 2. TEXT BOUNDS (every text rect)
for (const r of rects) {
  const b = bounds(r);
  if (b.l < safe.left || b.r > safe.right || b.t < safe.top || b.b > safe.bottom) {
    issues.push({ type: 'OOB', id: `${r.kind} "${r.text}"`,
      detail: `at (${r.pos[0].toFixed(0)},${r.pos[1].toFixed(0)}) ${(b.r - b.l).toFixed(0)}×${(b.b - b.t).toFixed(0)} exceeds frame [${safe.left}..${safe.right}]×[${safe.top}..${safe.bottom}]`,
      fix: `move/route so "${r.text}" sits inside the frame` });
  }
}

// 3. COLLISIONS (pairwise text-rect overlap)
const overlap = (a, b) => {
  const ix = Math.max(0, Math.min(a.r, b.r) - Math.max(a.l, b.l));
  const iy = Math.max(0, Math.min(a.b, b.b) - Math.max(a.t, b.t));
  return ix * iy;
};
for (let i = 0; i < rects.length; i++) {
  for (let j = i + 1; j < rects.length; j++) {
    const ov = overlap(bounds(rects[i]), bounds(rects[j]));
    if (ov > 0) {
      issues.push({ type: 'COLLISION', id: `"${rects[i].text}" ↔ "${rects[j].text}"`,
        detail: `${rects[i].source} ↔ ${rects[j].source}; overlap ${ov.toFixed(0)}px²`,
        fix: `shorten a label, route to a clear channel, or offset with labelT` });
    }
  }
}

// ── report ──
if (!issues.length) {
  console.log(`✓ ${spec.name}: all nodes & labels inside frame; no collisions. (canvas ${W}×${H}, frame inset ${FRAME})`);
  exit(0);
}
const oob = issues.filter((i) => i.type === 'OOB'), col = issues.filter((i) => i.type === 'COLLISION');
console.log(`✗ ${spec.name}: ${oob.length} out-of-bounds, ${col.length} collision(s)  (canvas ${W}×${H}, frame inset ${FRAME})\n`);
for (const i of issues) {
  console.log(`[${i.type}] ${i.id}`);
  console.log(`   ${i.detail}`);
  console.log(`   → fix: ${i.fix}\n`);
}
exit(1);
