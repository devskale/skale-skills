// Unit tests for layout(spec) — the resolved-geometry seam.
// Run:  node --test build/layout.test.mjs
// Expected values come from independent sources: hand-computed geometry (boxes, centers,
// polyline midpoints) and the geometric definition of normals — NOT by re-running the
// code under test (that would be tautological).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { layout } from './layout.mjs';

test('layout resolves node boxes: applies 150×150 default + computes center', () => {
  const model = layout({ nodes: [{ id: 'a', x: 40, y: 295 }] });
  assert.deepEqual(model.boxes.a, { x: 40, y: 295, w: 150, h: 150, cx: 115, cy: 370 });
});

test('layout honours explicit node size', () => {
  const model = layout({ nodes: [{ id: 'b', x: 100, y: 50, w: 200, h: 100 }] });
  assert.deepEqual(model.boxes.b, { x: 100, y: 50, w: 200, h: 100, cx: 200, cy: 100 });
});

test('layout carries canvas size with defaults', () => {
  assert.deepEqual(
    { w: layout({ nodes: [] }).width, h: layout({ nodes: [] }).height },
    { w: 1200, h: 800 }
  );
  const m = layout({ width: 1280, height: 660, nodes: [] });
  assert.equal(m.width, 1280);
  assert.equal(m.height, 660);
});

test('layout resolves the title with defaults', () => {
  const t = layout({ title: 'hello', nodes: [] }).title;
  assert.equal(t.x, 46); assert.equal(t.y, 62); assert.equal(t.size, 40); assert.equal(t.text, 'hello');
});

test('layout honours title position/size overrides', () => {
  const t = layout({ title: 't', titleX: 10, titleY: 20, titleSize: 30, nodes: [] }).title;
  assert.equal(t.x, 10); assert.equal(t.y, 20); assert.equal(t.size, 30); assert.equal(t.text, 't');
});

test('layout omits title when absent', () => {
  assert.equal(layout({ nodes: [] }).title, undefined);
});

// ── edge polylines ──
const ANCHOR_NODES = [
  { id: 'a', x: 0,   y: 0,   w: 100, h: 100 },   // cx 50  cy 50
  { id: 'b', x: 200, y: 0,   w: 100, h: 100 },   // cx 250 cy 50
  { id: 'c', x: 0,   y: 200, w: 100, h: 100 },   // cx 50  cy 250
];

const edgeModel = (edge) => layout({ nodes: ANCHOR_NODES, edges: [edge] }).edges[0];

test('edge uses an explicit path verbatim (dashed defaults true)', () => {
  const e = edgeModel({ from: 'a', to: 'b', path: [[10, 10], [20, 20]] });
  assert.deepEqual(e.pts, [[10, 10], [20, 20]]);
  assert.equal(e.dashed, true);
});

test('edge honours explicit fromSide/toSide anchors', () => {
  // a.right = [100,50], b.left = [200,50]
  const e = edgeModel({ from: 'a', to: 'b', fromSide: 'right', toSide: 'left' });
  assert.deepEqual(e.pts, [[100, 50], [200, 50]]);
});

test('edge auto-picks sides when none given (horizontal → right/left)', () => {
  const e = edgeModel({ from: 'a', to: 'b' });
  assert.deepEqual(e.pts, [[100, 50], [200, 50]]);
});

test('edge auto-picks sides when none given (vertical → bottom/top)', () => {
  // a.bottom = [50,100], c.top = [50,200]
  const e = edgeModel({ from: 'a', to: 'c' });
  assert.deepEqual(e.pts, [[50, 100], [50, 200]]);
});

test('edge honours dashed:false', () => {
  assert.equal(edgeModel({ from: 'a', to: 'b', dashed: false }).dashed, false);
});

// ── node labels: pos + dims resolved onto the box (so review can collide them) ──
test('node label sits low when an icon is present (y + h*0.78)', () => {
  const m = layout({ nodes: [{ id: 'n', x: 0, y: 0, w: 100, h: 100, icon: 'x', label: 'hi', labelSize: 20 }] });
  assert.deepEqual(m.boxes.n.label.pos, [50, 78]);   // cx=50, y+h*0.78=78
  assert.equal(m.boxes.n.label.size, 20);
});

test('node label centers vertically when there is no icon', () => {
  const m = layout({ nodes: [{ id: 'n', x: 0, y: 0, w: 100, h: 100, label: 'x' }] });
  assert.deepEqual(m.boxes.n.label.pos, [50, 50]);   // cx, cy
});

test('node without a label has no label field', () => {
  assert.equal(layout({ nodes: [{ id: 'n', x: 0, y: 0 }] }).boxes.n.label, undefined);
});

test('title carries halo dims (so review can bound it)', () => {
  // 'hello' 5 chars, size 40: w = 5*40*0.54+12 = 120 → halfW 60
  const m = layout({ title: 'hello', nodes: [] });
  assert.ok(Math.abs(m.title.halfW - 60) < 0.01);
  assert.ok(m.title.halfH > 0);
});

test('title pos is the visual CENTER (compose emits it left-anchored at x)', () => {
  // 'hello' size 40 → halfW 60; left-anchored at x=46 → center x = 46+60 = 106
  const t = layout({ title: 'hello', nodes: [] }).title;
  assert.equal(t.pos[0], 106);
  assert.equal(t.pos[1], 62);   // baseline y carried as the vertical center (approx)
});

// ── edge labels: position (pointAlong + upward normal × gap) + shared halo dims ──
// pts are horizontal [[0,100],[200,100]]; at t the normal points up (0,-1).
const labelOf = (edge) => layout({ nodes: ANCHOR_NODES, edges: [edge] }).edges[0].label;

test('label sits at midpoint, offset upward by gap=22 (no badge)', () => {
  const e = labelOf({ from: 'a', to: 'b', path: [[0, 100], [200, 100]], label: 'hi' });
  assert.deepEqual(e.pos, [100, 78]);          // 100 - 22
  assert.equal(e.text, 'hi');
  assert.equal(e.size, 19);
});

test('label widens its gap to 30 when the edge also has a badge', () => {
  const e = labelOf({ from: 'a', to: 'b', path: [[0, 100], [200, 100]], label: 'hi', badge: 1 });
  assert.deepEqual(e.pos, [100, 70]);          // 100 - 30
});

test('labelT moves the base point along the path', () => {
  const e = labelOf({ from: 'a', to: 'b', path: [[0, 100], [200, 100]], label: 'x', labelT: 0.25 });
  assert.deepEqual(e.pos, [50, 78]);           // 0.25*200=50, -22
});

test('labelOffset overrides the normal offset entirely', () => {
  const e = labelOf({ from: 'a', to: 'b', path: [[0, 100], [200, 100]], label: 'x', labelOffset: [5, -5] });
  assert.deepEqual(e.pos, [105, 95]);          // midpoint + offset, no normal
});

test('labelAt pins the base (normal still applies)', () => {
  const e = labelOf({ from: 'a', to: 'b', path: [[0, 100], [200, 100]], label: 'x', labelAt: [200, 200] });
  assert.deepEqual(e.pos, [200, 178]);         // 200 - 22
});

test('halo half-extents come from the shared textBox formula (≈hand-computed)', () => {
  // text 'hi' → 2 chars, 1 line, size 19: w=2*19*0.54+12=32.52, h=1*19*1.05+6=25.95
  const e = labelOf({ from: 'a', to: 'b', path: [[0, 100], [200, 100]], label: 'hi' });
  assert.ok(Math.abs(e.halfW - 16.26) < 0.01);
  assert.ok(Math.abs(e.halfH - 12.975) < 0.001);
});

test('halo width grows with text length (independent property)', () => {
  const short = labelOf({ from: 'a', to: 'b', path: [[0, 100], [200, 100]], label: 'ab' });
  const long = labelOf({ from: 'a', to: 'b', path: [[0, 100], [200, 100]], label: 'abcdefgh' });
  assert.ok(long.halfW > short.halfW);
});

// ── badges: clearPointOnPath snaps to the nearest clear point on the path ──
// nodes kept tiny + far from the path so every point is clear (predictable mid/source).
const CLEAR = [{ id: 's', x: 0, y: 0, w: 10, h: 10 }, { id: 't', x: 1000, y: 0, w: 10, h: 10 }];
const overlay = (edge) => layout({ nodes: CLEAR, edges: [edge] }).edges[0];

test('badge sits at path midpoint when nothing blocks (badgeT default 0.5)', () => {
  const e = overlay({ from: 's', to: 't', path: [[50, 500], [200, 500]], badge: 7 });
  assert.deepEqual(e.badge.pos, [125, 500]);   // midpoint of the 150-long path
  assert.equal(e.badge.n, 7);
});

test('badgeAt pins the badge exactly', () => {
  const e = overlay({ from: 's', to: 't', path: [[50, 500], [200, 500]], badge: 1, badgeAt: [7, 8] });
  assert.deepEqual(e.badge.pos, [7, 8]);
});

// ── branch (YES/NO): near source (branchT 0.2), offset up 24, uppercased ──
test('branch no → text NO, near source, offset up 24', () => {
  const e = overlay({ from: 's', to: 't', path: [[50, 500], [200, 500]], branch: 'no' });
  // t=0.2 → base [80,500]; normal up ×24 → [80,476]
  assert.deepEqual(e.branch.pos, [80, 476]);
  assert.equal(e.branch.text, 'NO');
});

test('branch yes uppercases to YES', () => {
  const e = overlay({ from: 's', to: 't', path: [[50, 500], [200, 500]], branch: 'yes' });
  assert.equal(e.branch.text, 'YES');
});

test('branchOffset overrides the normal offset', () => {
  const e = overlay({ from: 's', to: 't', path: [[50, 500], [200, 500]], branch: 'no', branchOffset: [3, 4] });
  // base clearPoint(0.2)=[80,500]; +offset → [83,504]
  assert.deepEqual(e.branch.pos, [83, 504]);
});
