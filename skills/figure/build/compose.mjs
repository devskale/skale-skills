// Figure compositor: turn a declarative spec into one house-style SVG that embeds the
// CC0 icon set, using the shared palette, Patrick Hand font, standard boxes, dashed
// arrows and numbered step badges. Same spec -> same figure, every time.
//
// This module is now PURE EMISSION: geometry (where every box, polyline, label, badge and
// branch lands) is resolved by layout() in ./layout.mjs. composeSVG reads that resolved
// model and turns it into SVG. Both this and review_figure consume the same model, so they
// can never disagree about positions. Width/dims come from the model too (textBox lives in
// layout.mjs — the single source).

import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { layout } from './layout.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));       // figure/build
const ICONS = join(HERE, '..', 'assets', 'icons');

export const PALETTE = {
  red: '#E8443A', amber: '#F5A623', green: '#7FB77E', greenFill: '#CDEAC0',
  lilac: '#B9A7D6', blue: '#6E9BD1', tan: '#C79A54', cream: '#F3E2C7',
  maroon: '#B4685F', badge: '#FDF0D0', frame: '#AFC7E8', ink: '#3A3A3A',
  paper: '#FCFDFF', muted: '#6a7b8c',
};
// Soft fills paired with each stroke colour (for node backgrounds).
const SOFT = {
  red: '#FBE3E1', amber: '#FDEFD6', green: '#E7F2E4', lilac: '#EBE3F3',
  blue: '#E3EDF7', tan: '#F3E2C7', maroon: '#F3E0DC',
};
const col = (c) => PALETTE[c] || c || PALETTE.ink;
const FONT = "'Patrick Hand', cursive";

// --- icon embedding (nested <svg>, our icons have no ids/defs so this is collision-free) ---
function iconEl(name, x, y, size) {
  const file = join(ICONS, `${name}.svg`);
  if (!existsSync(file)) throw new Error(`icon not found: ${name} (${file})`);
  const raw = readFileSync(file, 'utf8');
  const vb = (raw.match(/viewBox="([^"]+)"/) || [])[1] || '0 0 120 120';
  const inner = raw
    .replace(/<\?xml[\s\S]*?\?>/, '')
    .replace(/<svg[^>]*>/, '')
    .replace(/<\/svg>\s*$/, '');
  return `<svg x="${x}" y="${y}" width="${size}" height="${size}" viewBox="${vb}" overflow="visible">${inner}</svg>`;
}

// --- text (multi-line, centred) ---
function textEl(cx, cy, text, { size = 22, fill = PALETTE.ink, weight = 400, anchor = 'middle' } = {}) {
  const lines = String(text).split('\n');
  const lh = size * 1.05;
  const y0 = cy - ((lines.length - 1) * lh) / 2;
  const tspans = lines
    .map((ln, i) => `<tspan x="${cx}" y="${(y0 + i * lh).toFixed(1)}">${esc(ln)}</tspan>`)
    .join('');
  return `<text text-anchor="${anchor}" dominant-baseline="central" font-family="${FONT}" font-size="${size}" font-weight="${weight}" fill="${fill}">${tspans}</text>`;
}
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function badgeEl(x, y, n) {
  return `<g>
    <circle cx="${x}" cy="${y}" r="15" fill="${PALETTE.badge}" stroke="${PALETTE.amber}" stroke-width="2.4" stroke-dasharray="5 4" stroke-linecap="round"/>
    ${textEl(x, y, n, { size: 18 })}
  </g>`;
}
// Text with a soft paper-coloured halo behind it. Dims come FROM THE MODEL (pos ± half) —
// compose never computes width; textBox is layout.mjs's single source of truth.
function labelHalo(cx, cy, halfW, halfH, text, { size = 19, fill = PALETTE.ink, weight = 400 } = {}) {
  return `<g>
    <rect x="${(cx - halfW).toFixed(1)}" y="${(cy - halfH).toFixed(1)}" width="${(2 * halfW).toFixed(1)}" height="${(2 * halfH).toFixed(1)}" rx="7" fill="${PALETTE.paper}" opacity="0.9"/>
    ${textEl(cx, cy, text, { size, fill, weight })}
  </g>`;
}

export function composeSVG(spec) {
  const model = layout(spec);
  const W = model.width, H = model.height;
  const parts = [];

  // defs: arrowhead
  parts.push(`<defs>
    <marker id="arrow" viewBox="0 0 10 10" refX="8.5" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M1 1 L9 5 L1 9" fill="none" stroke="${PALETTE.ink}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
    </marker>
  </defs>`);

  // frame
  if (spec.frame !== false) {
    parts.push(`<rect x="6" y="6" width="${W - 12}" height="${H - 12}" rx="26" fill="${PALETTE.paper}" stroke="${col(spec.frameColor) || PALETTE.frame}" stroke-width="2.4"/>`);
  }

  // title — plain ink, no background swipe (removed house-wide 2026-07-25)
  if (model.title) {
    parts.push(`<text x="${model.title.x}" y="${model.title.y}" font-family="${FONT}" font-size="${model.title.size}" font-weight="700" fill="${PALETTE.ink}">${esc(model.title.text)}</text>`);
  }

  const overlays = []; // badges + labels: always drawn LAST, on top of nodes

  // edges: lines under nodes; badges/labels collected as overlays (drawn on top)
  for (const me of model.edges) {
    const d = me.pts.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
    const dash = me.dashed ? ' stroke-dasharray="7 6"' : '';
    parts.push(`<path d="${d}" fill="none" stroke="${PALETTE.ink}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"${dash} marker-end="url(#arrow)"/>`);

    if (me.label) {
      overlays.push(labelHalo(me.label.pos[0], me.label.pos[1], me.label.halfW, me.label.halfH, me.label.text, { size: me.label.size }));
    }
    if (me.branch) {
      const c = /^Y/i.test(me.branch.text) ? PALETTE.green : PALETTE.red;
      overlays.push(labelHalo(me.branch.pos[0], me.branch.pos[1], me.branch.halfW, me.branch.halfH, me.branch.text, { size: 20, fill: c, weight: 700 }));
    }
    if (me.badge != null) {
      overlays.push(badgeEl(me.badge.pos[0], me.badge.pos[1], me.badge.n));
    }
  }

  // nodes (drawn over edge lines, under overlays) — styling from spec, geometry from model
  for (const n of spec.nodes ?? []) {
    const b = model.boxes[n.id];
    const stroke = n.agent ? PALETTE.ink : col(n.color);
    const fill = n.fill ? col(n.fill) : (n.agent ? '#FFFFFF' : (SOFT[n.color] || '#FFFFFF'));
    if (!n.plain) {
      parts.push(`<rect x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" rx="16" fill="${fill}" stroke="${stroke}" stroke-width="2.6"/>`);
    }
    const hasLabel = n.label != null && n.label !== '';
    if (n.icon) {
      const size = n.iconSize ?? Math.min(b.w, b.h) * (hasLabel ? 0.5 : 0.72);
      const iconCx = b.cx, iconCy = hasLabel ? b.y + b.h * 0.36 : b.cy;
      parts.push(iconEl(n.icon, iconCx - size / 2, iconCy - size / 2, size));
    }
    if (hasLabel) {
      parts.push(textEl(b.label.pos[0], b.label.pos[1], b.label.text, { size: b.label.size }));
    }
  }

  // overlays: badges, edge labels, branch labels — always on top so nothing clips them
  parts.push(...overlays);

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${esc(spec.title || spec.name || 'figure')}">
${parts.join('\n')}
</svg>`;
}
