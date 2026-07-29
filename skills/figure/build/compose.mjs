// Figure compositor: turn a declarative spec into one house-style SVG that embeds the
// CC0 icon set, using the shared palette, Patrick Hand font, standard boxes, dashed
// arrows and numbered step badges. Same spec -> same figure, every time.
//
// A spec is a plain object (see ../diagrams/*.fig.mjs and ../build/README.md):
//   { name, title, width, height, frame?, nodes:[...], edges:[...] }
//   node: { id, x, y, w?, h?, icon?, label?, color?, fill?, agent?, plain? }
//   edge: { from, to, fromSide?, toSide?, path?, dashed?, badge?, label?, branch? }
// Coordinates are absolute; (x,y) is a node's top-left. Author on a loose grid.

import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

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

// --- node geometry ---
function nodeBox(n) {
  const w = n.w ?? 150, h = n.h ?? 150;
  return { x: n.x, y: n.y, w, h, cx: n.x + w / 2, cy: n.y + h / 2 };
}
function anchor(b, side) {
  switch (side) {
    case 'top': return [b.cx, b.y];
    case 'bottom': return [b.cx, b.y + b.h];
    case 'left': return [b.x, b.cy];
    case 'right': return [b.x + b.w, b.cy];
    default: return [b.cx, b.cy];
  }
}
function autoSides(a, b) {
  const dx = b.cx - a.cx, dy = b.cy - a.cy;
  if (Math.abs(dx) >= Math.abs(dy)) {
    return dx >= 0 ? ['right', 'left'] : ['left', 'right'];
  }
  return dy >= 0 ? ['bottom', 'top'] : ['top', 'bottom'];
}

// --- polyline helpers for badge/label placement ---
function pointAlong(pts, t) {
  const segs = [];
  let total = 0;
  for (let i = 1; i < pts.length; i++) {
    const d = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
    segs.push(d); total += d;
  }
  let target = t * total;
  for (let i = 0; i < segs.length; i++) {
    if (target <= segs[i] || i === segs.length - 1) {
      const f = segs[i] ? target / segs[i] : 0;
      return [pts[i][0] + (pts[i + 1][0] - pts[i][0]) * f,
              pts[i][1] + (pts[i + 1][1] - pts[i][1]) * f];
    }
    target -= segs[i];
  }
  return pts[pts.length - 1];
}

// Unit direction of the path at fraction t (for perpendicular label offsets).
function segDirAt(pts, t) {
  const segs = [];
  let total = 0;
  for (let i = 1; i < pts.length; i++) {
    const d = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
    segs.push(d); total += d;
  }
  if (!total) return [1, 0];
  let target = t * total;
  for (let i = 0; i < segs.length; i++) {
    if (target <= segs[i] || i === segs.length - 1) {
      const dx = pts[i + 1][0] - pts[i][0], dy = pts[i + 1][1] - pts[i][1];
      const L = Math.hypot(dx, dy) || 1;
      return [dx / L, dy / L];
    }
    target -= segs[i];
  }
  return [1, 0];
}
// Upward-ish unit normal at t, so labels sit clear of the line.
function normalAt(pts, t) {
  const [ux, uy] = segDirAt(pts, t);
  let nx = -uy, ny = ux;
  if (ny > 0) { nx = -nx; ny = -ny; } // prefer pointing up
  return [nx, ny];
}
function inAnyRect(p, rects, m) {
  return rects.some((r) => p[0] >= r.x - m && p[0] <= r.x + r.w + m &&
                           p[1] >= r.y - m && p[1] <= r.y + r.h + m);
}
// Point on the path nearest `preferredT` that is NOT inside/near any node box, so a
// badge always lands in clear whitespace (never clipped by or overlapping a box).
function clearPointOnPath(pts, rects, preferredT, m = 14) {
  let best = null, bestD = Infinity;
  for (let i = 0; i <= 240; i++) {
    const t = i / 240;
    const p = pointAlong(pts, t);
    if (inAnyRect(p, rects, m)) continue;
    const d = Math.abs(t - preferredT);
    if (d < bestD) { bestD = d; best = p; }
  }
  return best ?? pointAlong(pts, preferredT);
}

function badgeEl(x, y, n) {
  return `<g>
    <circle cx="${x}" cy="${y}" r="15" fill="${PALETTE.badge}" stroke="${PALETTE.amber}" stroke-width="2.4" stroke-dasharray="5 4" stroke-linecap="round"/>
    ${textEl(x, y, n, { size: 18 })}
  </g>`;
}
// Text with a soft paper-coloured halo behind it, so an edge label is legible even where
// it crosses a line and never reads as "hidden".
function labelHalo(cx, cy, text, { size = 19, fill = PALETTE.ink, weight = 400 } = {}) {
  const lines = String(text).split('\n');
  const maxLen = Math.max(1, ...lines.map((l) => l.length));
  const w = maxLen * size * 0.54 + 12;
  const h = lines.length * size * 1.05 + 6;
  return `<g>
    <rect x="${(cx - w / 2).toFixed(1)}" y="${(cy - h / 2).toFixed(1)}" width="${w.toFixed(1)}" height="${h.toFixed(1)}" rx="7" fill="${PALETTE.paper}" opacity="0.9"/>
    ${textEl(cx, cy, text, { size, fill, weight })}
  </g>`;
}

export function composeSVG(spec) {
  const W = spec.width ?? 1200, H = spec.height ?? 800;
  const boxes = Object.fromEntries(spec.nodes.map((n) => [n.id, { n, b: nodeBox(n) }]));
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
  if (spec.title) {
    const tx = spec.titleX ?? 46, ty = spec.titleY ?? 62, ts = spec.titleSize ?? 40;
    parts.push(`<text x="${tx}" y="${ty}" font-family="${FONT}" font-size="${ts}" font-weight="700" fill="${PALETTE.ink}">${esc(spec.title)}</text>`);
  }

  const rects = spec.nodes.map(nodeBox);
  const overlays = []; // badges + labels: always drawn LAST, on top of nodes

  // edges: lines under nodes; badges/labels collected as overlays (drawn on top)
  for (const e of spec.edges ?? []) {
    const A = boxes[e.from]?.b, B = boxes[e.to]?.b;
    let pts;
    if (e.path) {
      pts = e.path.slice();
    } else {
      const [sa, sb] = (e.fromSide && e.toSide) ? [e.fromSide, e.toSide] : autoSides(A, B);
      pts = [anchor(A, sa), anchor(B, sb)];
    }
    const d = pts.map((p, i) => `${i ? 'L' : 'M'}${p[0].toFixed(1)} ${p[1].toFixed(1)}`).join(' ');
    const dash = e.dashed === false ? '' : ' stroke-dasharray="7 6"';
    parts.push(`<path d="${d}" fill="none" stroke="${PALETTE.ink}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"${dash} marker-end="url(#arrow)"/>`);

    // edge label — perpendicular offset (clears the line + badge) with a halo
    if (e.label) {
      const t = e.labelT ?? 0.5;
      const base = e.labelAt ?? pointAlong(pts, t);
      let pos;
      if (e.labelOffset) pos = [base[0] + e.labelOffset[0], base[1] + e.labelOffset[1]];
      else {
        const [nx, ny] = normalAt(pts, t);
        const gap = e.badge != null ? 30 : 22; // clear the 15px badge when both present
        pos = [base[0] + nx * gap, base[1] + ny * gap];
      }
      overlays.push(labelHalo(pos[0], pos[1], e.label, { size: 19 }));
    }
    // branch YES/NO — near the source by default, offset off the line, coloured + halo
    if (e.branch) {
      const t = e.branchT ?? 0.2;
      const base = e.branchAt ?? clearPointOnPath(pts, rects, t);
      let pos;
      if (e.branchOffset) pos = [base[0] + e.branchOffset[0], base[1] + e.branchOffset[1]];
      else { const [nx, ny] = normalAt(pts, t); pos = [base[0] + nx * 24, base[1] + ny * 24]; }
      const c = /^y/i.test(e.branch) ? PALETTE.green : PALETTE.red;
      overlays.push(labelHalo(pos[0], pos[1], e.branch.toUpperCase(), { size: 20, fill: c, weight: 700 }));
    }
    // step badge — snapped to the nearest clear whitespace on the path (never on a box)
    if (e.badge != null) {
      const bp = e.badgeAt ?? clearPointOnPath(pts, rects, e.badgeT ?? 0.5);
      overlays.push(badgeEl(bp[0], bp[1], e.badge));
    }
  }

  // nodes (drawn over edge lines, under overlays)
  for (const n of spec.nodes) {
    const b = nodeBox(n);
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
      const ly = n.icon ? b.y + b.h * 0.78 : b.cy;
      parts.push(textEl(b.cx, ly, n.label, { size: n.labelSize ?? 20 }));
    }
  }

  // overlays: badges, edge labels, branch labels — always on top so nothing clips them
  parts.push(...overlays);

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" role="img" aria-label="${esc(spec.title || spec.name || 'figure')}">
${parts.join('\n')}
</svg>`;
}
