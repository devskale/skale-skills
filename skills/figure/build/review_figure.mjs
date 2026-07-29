#!/usr/bin/env node
// review_figure.mjs — a figure reviewer: catches out-of-bounds elements + label collisions.
//
// Two failure classes the compositor can't catch on its own:
//   1. OUT OF BOUNDS — a node box, edge label, or badge that pokes outside the frame
//      (the frame is drawn at a 6px inset, so the safe area is [6, W-6] × [6, H-6]).
//      e.g. a node whose bottom = H sits exactly on the canvas edge and clips the frame.
//   2. LABEL COLLISIONS — two labels/badges whose bboxes overlap (reused from
//      detect_label_collisions.mjs logic).
//
// Reads the SPEC (.fig.mjs) for node boxes + canvas size, and the rendered SVG for actual
// label/badge/badge positions. Reports every issue with the offending element + a suggested
// minimal fix, then exits non-zero if anything is wrong — so it slots into a refine loop:
//
//      build -> review -> (fix) -> build -> review ... until clean.
//
// Usage:  node review_figure.mjs path/to/figure.fig.mjs
//         (derives the .svg sibling automatically; builds it first if missing)

import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { argv, exit } from 'node:process';

const specPath = argv[2];
if (!specPath) { console.error('usage: node review_figure.mjs <figure.fig.mjs>'); exit(1); }

const specURL = pathToFileURL(specPath).href;
const mod = await import(specURL);
const spec = mod.default;
const W = spec.width, H = spec.height;
const svgPath = specPath.replace(/\.fig\.mjs$/, '.svg');
if (!existsSync(svgPath)) {
  console.error(`✗ missing SVG: ${svgPath} — build the figure first`);
  exit(2);
}
const svg = readFileSync(svgPath, 'utf8');

// ── frame geometry (must match compose.mjs: frame inset = 6px) ──
const FRAME_INSET = 6;
const BREATHING = 6;            // how much clearance inside the frame we want before warning
const safe = {
  left: FRAME_INSET, right: W - FRAME_INSET,
  top: FRAME_INSET, bottom: H - FRAME_INSET,
};
const ideal = {                       // a little clearance -> "ideally inside this"
  left: FRAME_INSET + BREATHING, right: W - FRAME_INSET - BREATHING,
  top: FRAME_INSET + BREATHING, bottom: H - FRAME_INSET - BREATHING,
};

const issues = [];

// ────────────────────────────────────────────────────────────────
// 1. NODE BOUNDS (from the spec — exact boxes)
// ────────────────────────────────────────────────────────────────
for (const n of spec.nodes) {
  if (n.plain) continue;              // plain = label-only, no box to bound
  const w = n.w ?? 150, h = n.h ?? 150;
  const l = n.x, r = n.x + w, t = n.y, b = n.y + h;
  // ERROR: outside the frame entirely
  if (l < safe.left || r > safe.right || t < safe.top || b > safe.bottom) {
    const over = [];
    if (l < safe.left) over.push(`left ${safe.left - l}px over`);
    if (r > safe.right) over.push(`right ${r - safe.right}px over`);
    if (t < safe.top) over.push(`top ${safe.top - t}px over`);
    if (b > safe.bottom) over.push(`bottom ${b - safe.bottom}px over`);
    // suggest the minimal fix
    const dx = Math.max(0, safe.left - l) + Math.max(0, r - safe.right);
    const dy = Math.max(0, safe.top - t) + Math.max(0, b - safe.bottom);
    const fix = [];
    if (b > safe.bottom) fix.push(`move "${n.id}" up by ${Math.ceil(b - safe.bottom)}px (y ${n.y}→${n.y - Math.ceil(b - safe.bottom)}) or raise canvas height to ${H + Math.ceil(b - safe.bottom)}`);
    if (r > safe.right) fix.push(`move "${n.id}" left by ${Math.ceil(r - safe.right)}px or widen canvas to ${W + Math.ceil(r - safe.right)}`);
    if (l < safe.left) fix.push(`move "${n.id}" right by ${Math.ceil(safe.left - l)}px`);
    if (t < safe.top) fix.push(`move "${n.id}" down by ${Math.ceil(safe.top - t)}px`);
    issues.push({ type: 'OOB', id: n.id, detail: `node box [${l},${t} ${w}×${h}] bottom=${b} right=${r}; ${over.join(', ')}`, fix: fix.join('; ') });
  }
}

// ────────────────────────────────────────────────────────────────
// 2. TEXT BOUNDS + COLLISIONS (from the rendered SVG — labels, badges, branches)
// ────────────────────────────────────────────────────────────────
const labels = [];
const textRe = /<text\b([^>]*)>([\s\S]*?)<\/text>/g;
let m, groupIdx = 0;
while ((m = textRe.exec(svg)) !== null) {
  const attrs = m[1], inner = m[2];
  const size = parseFloat((attrs.match(/font-size="([\d.]+)"/) || [])[1] || 16);
  const anchor = (attrs.match(/text-anchor="(\w+)"/) || [])[1] || 'start';
  const group = groupIdx++;
  const tspanRe = /<tspan\b([^>]*)>([^<]*)<\/tspan>/g;
  let tm, tspans = [];
  while ((tm = tspanRe.exec(inner)) !== null) {
    const ta = tm[1], txt = tm[2];
    if (!txt.trim()) continue;
    const x = parseFloat((ta.match(/x="([\d.]+)"/) || [])[1] ?? 0);
    const y = parseFloat((ta.match(/y="([\d.]+)"/) || [])[1] ?? 0);
    tspans.push({ x, y, text: txt });
  }
  if (!tspans.length) {
    // no tspans — use the <text> element's own x/y (e.g. the title) instead of (0,0)
    const tx = parseFloat((attrs.match(/\bx="([\d.]+)"/) || [])[1] ?? 0);
    const ty = parseFloat((attrs.match(/\by="([\d.]+)"/) || [])[1] ?? 0);
    const s = inner.replace(/<[^>]+>/g, '').trim();
    if (s) tspans = [{ x: tx, y: ty, text: s }];
  }
  for (const t of tspans) {
    const text = t.text;
    const w = text.length * size * 0.55, h = size * 1.25;
    let cx = t.x;
    if (anchor === 'middle') cx -= w / 2; else if (anchor === 'end') cx -= w;
    const cy = t.y - h / 2;
    const kind = /^\d{1,2}$/.test(text.trim()) ? 'badge' : /^(YES|NO)$/i.test(text.trim()) ? 'branch' : 'label';
    labels.push({ kind, text, x: cx, y: cy, w, h, size, group });
  }
}

// 2a. text out of frame
for (const lb of labels) {
  if (lb.x < safe.left || lb.x + lb.w > safe.right || lb.y < safe.top || lb.y + lb.h > safe.bottom) {
    issues.push({ type: 'OOB', id: `"${lb.text}"`, detail: `${lb.kind} at (${lb.x.toFixed(0)},${lb.y.toFixed(0)}) ${lb.w.toFixed(0)}×${lb.h.toFixed(0)} exceeds frame [${safe.left}..${safe.right}]×[${safe.top}..${safe.bottom}]`, fix: `move/route so "${lb.text}" sits inside the frame` });
  }
}

// 2b. text-text collisions (skip tspans sharing a parent <text> = multi-line node label)
function overlap(a, b) {
  const ix = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
  const iy = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
  return ix * iy;
}
for (let i = 0; i < labels.length; i++)
  for (let j = i + 1; j < labels.length; j++) {
    const a = labels[i], b = labels[j];
    if (a.group === b.group) continue;
    const ov = overlap(a, b);
    if (ov > 0) issues.push({ type: 'COLLISION', id: `"${a.text}"↔"${b.text}"`, detail: `overlap ${ov.toFixed(0)}px²`, fix: `shorten a label, route to a clear channel, or offset with labelT` });
  }

// ────────────────────────────────────────────────────────────────
// report
// ────────────────────────────────────────────────────────────────
if (!issues.length) {
  console.log(`✓ ${spec.name}: all nodes & labels inside frame; no collisions. (canvas ${W}×${H}, frame inset ${FRAME_INSET})`);
  exit(0);
}
const oob = issues.filter(i => i.type === 'OOB'), col = issues.filter(i => i.type === 'COLLISION');
console.log(`✗ ${spec.name}: ${oob.length} out-of-bounds, ${col.length} collision(s)  (canvas ${W}×${H}, frame inset ${FRAME_INSET})\n`);
for (const i of issues) {
  console.log(`[${i.type}] ${i.id}`);
  console.log(`   ${i.detail}`);
  console.log(`   → fix: ${i.fix}\n`);
}
exit(1);
