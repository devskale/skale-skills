#!/usr/bin/env node
// Render a PNG next to every SVG under figure/assets/ (and any dirs passed as args).
// House rule: every SVG we create ships with a matching PNG so it can be viewed anywhere
// (e.g. on a phone). PNGs are written at a high scale for crisp preview.
//
// Usage:
//   node figure/assets/render_pngs.mjs [dir ...]
// Uses `rsvg-convert` (librsvg) — a lightweight native rasterizer, cross-platform
// (Homebrew on macOS, librsvg2-bin on Linux). No Chromium/Playwright download. The
// Patrick Hand house font is embedded as a data: URI in the SVG, so text renders
// correctly (never a sans fallback).

import { readdirSync, existsSync, writeFileSync, readFileSync } from 'node:fs';
import { join, dirname, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { renderSVG } from '../build/raster.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));           // figure/assets
const SCALE = 4;                                               // 120px art -> 480px PNG

function walkSvgs(dir) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...walkSvgs(p));
    else if (e.isFile() && e.name.toLowerCase().endsWith('.svg')) out.push(p);
  }
  return out;
}

const targets = process.argv.slice(2).map((d) => resolve(d));
const roots = targets.length ? targets : [HERE];
const svgs = roots.flatMap((r) => (existsSync(r) ? walkSvgs(r) : []));
if (!svgs.length) { console.log('no SVGs found'); process.exit(0); }

let failed = 0;
for (const svgPath of svgs) {
  const svg = readFileSync(svgPath, 'utf8');
  const pngPath = svgPath.replace(/\.svg$/i, '.png');
  try {
    const png = renderSVG(svg, SCALE);
    writeFileSync(pngPath, png);
    console.log('rendered', relative(process.cwd(), pngPath));
  } catch (e) {
    process.stderr.write(`⚠ ${relative(process.cwd(), svgPath)} — PNG render skipped: ${e.message}\n`);
    failed++;
  }
}
if (failed) process.exit(1);
