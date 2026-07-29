// Shared SVG -> PNG rasterizer for the figure toolchain.
// One code path for both the icon previews (assets/render_pngs.mjs) and composed
// diagrams (build_figures.mjs). Loads the Patrick Hand house font so text never falls
// back to a sans.

import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const HERE = dirname(fileURLToPath(import.meta.url)); // figure/build
export const FONT_PATH = join(HERE, '..', 'assets', 'fonts', 'PatrickHand-Regular.ttf');

// Locate the bundled Chromium regardless of its exact revision dir; fall back to
// Playwright's own resolution if the managed path isn't present.
export function findChrome() {
  const root = process.env.PLAYWRIGHT_BROWSERS_PATH || '/opt/pw-browsers';
  if (existsSync(root)) {
    for (const d of readdirSync(root)) {
      if (!d.startsWith('chromium-')) continue;
      for (const p of [join(root, d, 'chrome-linux', 'chrome'),
                       join(root, d, 'chrome-linux', 'headless_shell')]) {
        if (existsSync(p)) return p;
      }
    }
  }
  return undefined;
}

export function fontFaceCss() {
  if (!existsSync(FONT_PATH)) return '';
  const b64 = readFileSync(FONT_PATH).toString('base64');
  return `@font-face{font-family:'Patrick Hand';src:url(data:font/ttf;base64,${b64});}`;
}

export function svgSize(svg) {
  const m = svg.match(/viewBox="([\d.\s-]+)"/);
  if (m) { const [, , w, h] = m[1].trim().split(/\s+/).map(Number); return { w, h }; }
  const w = Number((svg.match(/\bwidth="(\d+)/) || [])[1]) || 120;
  const h = Number((svg.match(/\bheight="(\d+)/) || [])[1]) || 120;
  return { w, h };
}

// Run fn with a ready Chromium page, always closing the browser afterwards.
export async function withPage(fn) {
  const browser = await chromium.launch({ executablePath: findChrome() });
  try {
    const page = await browser.newPage({ deviceScaleFactor: 1 });
    return await fn(page);
  } finally {
    await browser.close();
  }
}

// Render one SVG string to a transparent PNG buffer at `scale`x.
export async function renderSVG(page, svg, scale = 4) {
  const { w, h } = svgSize(svg);
  const W = Math.max(1, Math.round(w * scale));
  const H = Math.max(1, Math.round(h * scale));
  await page.setViewportSize({ width: W, height: H });
  await page.setContent(
    `<!doctype html><meta charset="utf-8"><style>${fontFaceCss()}
       html,body{margin:0;padding:0;background:transparent}
       body>svg{display:block;width:${W}px;height:${H}px}</style>${svg}`,
    { waitUntil: 'networkidle' }
  );
  await page.evaluate(() => (document.fonts ? document.fonts.ready : null));
  return page.locator('svg').first().screenshot({ omitBackground: true });
}
