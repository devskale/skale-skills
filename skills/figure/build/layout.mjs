// layout(spec) — the resolved-geometry seam.
//
// Turns a declarative figure spec into a pure-data model of WHERE everything is:
// resolved node boxes, edge polylines, and the positions + halo dims of every label /
// badge / branch. Both consumers of a figure — composeSVG (model → SVG) and review_figure
// (model → bounds/collisions) — read THIS, so geometry has one home and they can never
// disagree.
//
// The model is additive: a new overlay kind is a new optional field, not a rewrite.
//
// NOTE on label width: halfW/halfH come from one shared heuristic (textBox) — the same
// formula composeSVG uses for its halo. True font-metric width needs rendering; this makes
// the two consumers AGREE on the rect rather than be exact. If real metrics (opentype.js)
// ever land, textBox is the single swap point.

// resolved box: { x, y, w, h, cx, cy }
function boxOf(n) {
  const w = n.w ?? 150, h = n.h ?? 150;
  return { x: n.x, y: n.y, w, h, cx: n.x + w / 2, cy: n.y + h / 2 };
}

// anchor point of a box on a given side (or its center if side unknown)
function anchor(b, side) {
  switch (side) {
    case 'top':    return [b.cx, b.y];
    case 'bottom': return [b.cx, b.y + b.h];
    case 'left':   return [b.x, b.cy];
    case 'right':  return [b.x + b.w, b.cy];
    default:       return [b.cx, b.cy];
  }
}

// auto-pick source/target sides from the two boxes' relative position
function autoSides(a, b) {
  const dx = b.cx - a.cx, dy = b.cy - a.cy;
  if (Math.abs(dx) >= Math.abs(dy)) return dx >= 0 ? ['right', 'left'] : ['left', 'right'];
  return dy >= 0 ? ['bottom', 'top'] : ['top', 'bottom'];
}

// resolve one edge's polyline (explicit path wins; else anchors by given/auto sides)
function edgePts(e, boxes) {
  if (e.path) return e.path.slice();
  const A = boxes[e.from], B = boxes[e.to];
  const [sa, sb] = (e.fromSide && e.toSide) ? [e.fromSide, e.toSide] : autoSides(A, B);
  return [anchor(A, sa), anchor(B, sb)];
}

// cumulative segment lengths of a polyline: { segs:[], total } — shared by pointAlong
// and segDirAt so the length walk lives in one place.
function segLengths(pts) {
  const segs = [];
  let total = 0;
  for (let i = 1; i < pts.length; i++) {
    const d = Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
    segs.push(d); total += d;
  }
  return { segs, total };
}

// point at fraction t along a polyline
function pointAlong(pts, t) {
  const { segs, total } = segLengths(pts);
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

// unit direction of the path at fraction t
function segDirAt(pts, t) {
  const { segs, total } = segLengths(pts);
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

// upward-ish unit normal at t, so labels sit clear of the line
function normalAt(pts, t) {
  const [ux, uy] = segDirAt(pts, t);
  let nx = -uy, ny = ux;
  if (ny > 0) { nx = -nx; ny = -ny; }   // prefer pointing up
  return [nx, ny];
}

// SHARED halo dims for a label — the single width model both compose and review use.
// halfW/halfH are half-extents so a consumer forms the rect as pos ± half.
// (Heuristic: true font-metric width needs rendering; this makes consumers AGREE. Swap
// point for real metrics here, one place.) Exported so emitters can stay in sync if needed.
export function textBox(text, size) {
  const lines = String(text).split('\n');
  const maxLen = Math.max(1, ...lines.map((l) => l.length));
  return {
    halfW: (maxLen * size * 0.54 + 12) / 2,
    halfH: (lines.length * size * 1.05 + 6) / 2,
  };
}

// resolve a label overlay: { pos, halfW, halfH, text, size } (pos from path geometry)
function resolveLabel(e, pts) {
  const size = 19;
  const t = e.labelT ?? 0.5;
  const base = e.labelAt ?? pointAlong(pts, t);
  let pos;
  if (e.labelOffset) {
    pos = [base[0] + e.labelOffset[0], base[1] + e.labelOffset[1]];
  } else {
    const [nx, ny] = normalAt(pts, t);
    const gap = e.badge != null ? 30 : 22;      // clear the 15px badge when both present
    pos = [base[0] + nx * gap, base[1] + ny * gap];
  }
  return { pos, text: e.label, size, ...textBox(e.label, size) };
}

// resolve a branch (YES/NO) overlay: { pos, text } (near source, offset off the line)
function resolveBranch(e, pts, rects) {
  const t = e.branchT ?? 0.2;
  const base = e.branchAt ?? clearPointOnPath(pts, rects, t);
  let pos;
  if (e.branchOffset) {
    pos = [base[0] + e.branchOffset[0], base[1] + e.branchOffset[1]];
  } else {
    const [nx, ny] = normalAt(pts, t);
    pos = [base[0] + nx * 24, base[1] + ny * 24];
  }
  const text = String(e.branch).toUpperCase();
  return { pos, text, ...textBox(text, 20) };
}

// is point p within margin m of any node rect?
function inAnyRect(p, rects, m) {
  return rects.some((r) => p[0] >= r.x - m && p[0] <= r.x + r.w + m &&
                           p[1] >= r.y - m && p[1] <= r.y + r.h + m);
}

// point on the path nearest preferredT that is NOT inside/near any node box, so a
// badge/branch always lands in clear whitespace (never clipped by or overlapping a box).
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

export function layout(spec) {
  const width = spec.width ?? 1200;
  const height = spec.height ?? 800;
  const nodes = spec.nodes ?? [];
  const boxes = Object.fromEntries(nodes.map((n) => {
    const b = boxOf(n);
    // resolve the node's own label onto the box (pos + dims) — single source for both
    // compose's emission and review's collision check.
    if (n.label != null && n.label !== '') {
      const size = n.labelSize ?? 20;
      const ly = n.icon ? b.y + b.h * 0.78 : b.cy;
      b.label = { pos: [b.cx, ly], text: n.label, size, ...textBox(n.label, size) };
    }
    return [n.id, b];
  }));
  const title = (() => {
    if (spec.title == null) return undefined;
    const x = spec.titleX ?? 46, y = spec.titleY ?? 62, size = spec.titleSize ?? 40;
    const dims = textBox(spec.title, size);
    // compose emits the title LEFT-anchored at (x, y-baseline); review needs the visual
    // center, so pos = [x + halfW, y]. (Vertical y is the baseline; carried as an
    // approximate center — titles sit top-left with headroom, so this is plenty for bounds.)
    return { x, y, size, text: spec.title, ...dims, pos: [x + dims.halfW, y] };
  })();
  const edges = (spec.edges ?? []).map((e) => {
    const pts = edgePts(e, boxes);
    const out = { from: e.from, to: e.to, pts, dashed: e.dashed === false ? false : true };
    if (e.label != null) out.label = resolveLabel(e, pts);
    if (e.badge != null || e.branch != null) {
      const rects = Object.values(boxes);          // hoisted: computed once per edge
      if (e.badge != null) out.badge = { pos: e.badgeAt ?? clearPointOnPath(pts, rects, e.badgeT ?? 0.5), n: e.badge, halfW: 16, halfH: 16 };
      if (e.branch != null) out.branch = resolveBranch(e, pts, rects);
    }
    return out;
  });
  return { width, height, boxes, title, edges };
}
