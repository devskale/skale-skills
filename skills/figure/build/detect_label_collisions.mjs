#!/usr/bin/env node
// detect_label_collisions.mjs — find overlapping text labels in a figure SVG.
//
// Parses every <text>/<tspan> in the SVG, estimates each label's bounding box
// from its text length + font size, and reports any pair whose boxes overlap.
//
// Usage:  node detect_label_collisions.mjs path/to/figure.svg
//
// Heuristic bbox: width ≈ chars * fontSize * 0.55 (Patrick Hand is ~narrow);
// height ≈ fontSize * 1.25. text-anchor=middle → center on x; else left-anchored.
// This is an estimate (no font metrics) but catches the real overlaps in practice.

import { readFileSync } from 'node:fs';
import { argv } from 'node:process';

const svgPath = argv[2];
if (!svgPath) { console.error('usage: node detect_label_collisions.mjs <figure.svg>'); process.exit(1); }
const svg = readFileSync(svgPath, 'utf8');

// each entry: { kind, text, x, y, w, h, size, anchor, group }
// `group` = index of the parent <text> block, so multi-line node labels (several
// tspans in ONE <text>) can be skipped — they're intentional stacked lines, not
// separate labels that could collide meaningfully.
const labels = [];

// match <text ...>...</text> blocks, then pull tspans + the text's own attrs
const textRe = /<text\b([^>]*)>([\s\S]*?)<\/text>/g;
let m;
let groupIdx = 0;
while ((m = textRe.exec(svg)) !== null) {
  const attrs = m[1];
  const inner = m[2];
  const sizeMatch = attrs.match(/font-size="([\d.]+)"/);
  const anchorMatch = attrs.match(/text-anchor="(\w+)"/);
  const size = sizeMatch ? parseFloat(sizeMatch[1]) : 16;
  const anchor = anchorMatch ? anchorMatch[1] : 'start';
  const group = groupIdx++;

  // collect tspans (each is a line); if none, treat inner text as one line
  const tspanRe = /<tspan\b([^>]*)>([^<]*)<\/tspan>/g;
  let tm;
  let tspans = [];
  while ((tm = tspanRe.exec(inner)) !== null) {
    const ta = tm[1];
    const tx = ta.match(/x="([\d.]+)"/);
    const ty = ta.match(/y="([\d.]+)"/);
    const txt = tm[2];
    if (txt.trim()) tspans.push({ x: tx ? parseFloat(tx[1]) : null, y: ty ? parseFloat(ty[1]) : null, text: txt });
  }
  if (!tspans.length) {
    const stripped = inner.replace(/<[^>]+>/g, '').trim();
    if (stripped) tspans = [{ x: null, y: null, text: stripped }];
  }

  for (const t of tspans) {
    const text = t.text;
    const w = text.length * size * 0.55;
    const h = size * 1.25;
    let cx = t.x ?? 0;
    if (anchor === 'middle') cx -= w / 2;
    else if (anchor === 'end') cx -= w;
    const cy = (t.y ?? 0) - h / 2;
    // classify: badge (1-2 digits), branch (YES/NO), or label (else)
    const kind = /^\d{1,2}$/.test(text.trim()) ? 'badge'
      : /^(YES|NO)$/i.test(text.trim()) ? 'branch'
      : 'label';
    labels.push({ kind, text, x: cx, y: cy, w, h, size, group });
  }
}

// find overlapping pairs (axis-aligned bbox intersection)
function overlap(a, b) {
  const ix = Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x));
  const iy = Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));
  return ix * iy;
}

let hits = 0;
for (let i = 0; i < labels.length; i++) {
  for (let j = i + 1; j < labels.length; j++) {
    const a = labels[i], b = labels[j];
    // skip two tspans that belong to the SAME <text> block (multi-line node label —
    // intentional stacking, not a collision)
    if (a.group === b.group) continue;
    const ov = overlap(a, b);
    if (ov > 0) {
      hits++;
      console.log(`OVERLAP  [${a.kind}] "${a.text}"  ↔  [${b.kind}] "${b.text}"`);
      console.log(`  a: x=${a.x.toFixed(0)} y=${a.y.toFixed(0)} w=${a.w.toFixed(0)} h=${a.h.toFixed(0)}  (size ${a.size})`);
      console.log(`  b: x=${b.x.toFixed(0)} y=${b.y.toFixed(0)} w=${b.w.toFixed(0)} h=${b.h.toFixed(0)}  (size ${b.size})`);
      console.log(`  overlap area: ${ov.toFixed(0)} px²`);
      console.log();
    }
  }
}
console.log(hits === 0 ? '✓ no label collisions detected' : `${hits} collision(s) detected`);
process.exit(hits === 0 ? 0 : 1);
