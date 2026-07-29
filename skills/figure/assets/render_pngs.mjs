#!/usr/bin/env node
// Render a PNG next to every SVG under figure/assets/ (and any dirs passed as args).
// House rule: every SVG we create ships with a matching PNG so it can be viewed anywhere
// (e.g. on a phone). PNGs are written at a high scale for crisp preview.
//
// Usage:
//   NODE_PATH=/opt/node22/lib/node_modules node figure/assets/render_pngs.mjs [dir ...]
// Requires Playwright's Chromium. The Patrick Hand house font is loaded so text renders
// correctly (never a sans fallback).

import { readdirSync, existsSync, readFileSync } from 'node:fs';
import { join, dirname, resolve, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

// Resolve Playwright from wherever it's installed (honours NODE_PATH, unlike bare ESM import).
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const HERE = dirname(fileURLToPath(import.meta.url));           // figure/assets
const FONT = join(HERE, 'fonts', 'PatrickHand-Regular.ttf');
const SCALE = 4;                                               // 120px art -> 480px PNG

// Find the bundled Chromium regardless of the exact revision dir.
function findChrome() {
  const root = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  for (const d of (existsSync(root) ? readdirSync(root) : [])) {
    const p = join(root, d, 'chrome-linux', 'chrome');
    if (d.startsWith('chromium-') && existsSync(p)) return p;
  }
  return undefined; // let Playwright resolve its default
}

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

const fontB64 = existsSync(FONT) ? readFileSync(FONT).toString('base64') : null;
const fontCss = fontB64
  ? `@font-face{font-family:'Patrick Hand';src:url(data:font/ttf;base64,${fontB64});}`
  : '';

const browser = await chromium.launch({ executablePath: findChrome() });
const page = await browser.newPage({ deviceScaleFactor: 1 });

for (const svgPath of svgs) {
  const svg = readFileSync(svgPath, 'utf8');
  const m = svg.match(/viewBox="([\d.\s-]+)"/);
  const [, , , vw, vh] = m ? m[1].trim().split(/\s+/).map(Number) : [0, 0, 120, 120];
  const w = Math.round((vw || 120) * SCALE);
  const h = Math.round((vh || 120) * SCALE);
  await page.setViewportSize({ width: w, height: h });
  await page.setContent(
    `<!doctype html><meta charset="utf-8">
     <style>${fontCss}
       html,body{margin:0;padding:0;background:transparent}
       svg{display:block;width:${w}px;height:${h}px}</style>${svg}`,
    { waitUntil: 'networkidle' }
  );
  await page.evaluate(() => document.fonts && document.fonts.ready);
  const pngPath = svgPath.replace(/\.svg$/i, '.png');
  await page.locator('svg').screenshot({ path: pngPath, omitBackground: true });
  console.log('rendered', relative(process.cwd(), pngPath));
}

await browser.close();
