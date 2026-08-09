#!/usr/bin/env node
// Build every figure spec into a matching SVG + PNG, consistently.
//
//   NODE_PATH=/opt/node22/lib/node_modules node figure/build/build_figures.mjs [spec.fig.mjs ...]
//
// With no args it builds every *.fig.mjs under figure/diagrams/, RECURSIVELY — specs are
// organised in per-topic subfolders (e.g. diagrams/architectures/). Each spec module
// default-exports a spec object (see compose.mjs). Rendered images (.svg + .png) are
// written to a dedicated OUTPUT dir, NOT next to the spec, so the skill's diagrams/
// stays clean. Output dir is XDG-standard: $XDG_CACHE_HOME/generated (default
// ~/.cache/generated); override with FIGURE_OUT_DIR.

import { readdirSync, existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname, resolve, basename } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { composeSVG } from './compose.mjs';
import { renderSVG } from './raster.mjs';
import { reviewSpec } from './review_figure.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));            // figure/build
const DIAGRAMS = join(HERE, '..', 'diagrams');
const SCALE = 2;                                                // figures are already large

// Resolve the output dir — XDG-standard cache home for regenerable generated output.
//   $XDG_CACHE_HOME/generated  (default ~/.cache/generated); FIGURE_OUT_DIR overrides.
function resolveOutDir() {
  const override = process.env.FIGURE_OUT_DIR?.trim();
  if (override) return resolve(override);
  const xdgCache = process.env.XDG_CACHE_HOME?.trim();
  const base = xdgCache ? resolve(xdgCache) : join(homedir(), '.cache');
  return join(base, 'generated');
}
const OUT_DIR = resolveOutDir();

// Walk a directory tree and collect every *.fig.mjs spec (any depth).
function findSpecs(dir) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...findSpecs(p));
    else if (e.name.endsWith('.fig.mjs')) out.push(p);
  }
  return out;
}

const args = process.argv.slice(2).map((a) => resolve(a));
const specs = args.length ? args : (existsSync(DIAGRAMS) ? findSpecs(DIAGRAMS) : []);

if (!specs.length) { console.log('no *.fig.mjs specs found under figure/diagrams/'); process.exit(0); }

let failed = 0;
for (const specPath of specs) {
  const mod = await import(pathToFileURL(specPath).href);
  const spec = mod.default;
  const name = spec.name || basename(specPath).replace(/\.fig\.mjs$/, '');

  // Always-on lint (pre-render, dep-free): warnings → stderr (non-blocking);
  // errors (e.g. a dangling edge endpoint) → skip render and fail the build.
  const review = reviewSpec(spec);
  const errs = review.issues.filter((i) => i.severity === 'error');
  const warns = review.issues.filter((i) => i.severity === 'warning');
  if (warns.length) {
    process.stderr.write(`lint: ${name} — ${warns.length} warning(s)\n`);
    for (const w of warns) process.stderr.write(`  [${w.type}] ${w.id}: ${w.detail}\n`);
  }
  if (errs.length) {
    process.stderr.write(`✗ ${name} — ${errs.length} error(s); render skipped:\n`);
    for (const e of errs) process.stderr.write(`  [${e.type}] ${e.id}: ${e.detail}\n`);
    failed++;
    continue;
  }

  const outDir = join(OUT_DIR, name);                        // -> <out>/<name>/
  mkdirSync(outDir, { recursive: true });
  const svg = composeSVG(spec);
  writeFileSync(join(outDir, `${name}.svg`), svg + '\n');
  try {
    const png = renderSVG(svg, SCALE);
    writeFileSync(join(outDir, `${name}.png`), png);
  } catch (e) {
    // PNG rasterization is optional (rsvg-convert may be absent); the SVG is still valid.
    process.stderr.write(`⚠ ${name} — PNG render skipped: ${e.message}\n`);
  }
  console.log('built', name, '->', join(outDir, `${name}.svg`), '+', join(outDir, `${name}.png`));
}
if (failed) process.exit(1);
