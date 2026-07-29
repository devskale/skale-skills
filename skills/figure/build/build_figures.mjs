#!/usr/bin/env node
// Build every figure spec into a matching SVG + PNG, consistently.
//
//   NODE_PATH=/opt/node22/lib/node_modules node figure/build/build_figures.mjs [spec.fig.mjs ...]
//
// With no args it builds every *.fig.mjs under figure/diagrams/, RECURSIVELY — specs are
// organised in per-topic subfolders (e.g. diagrams/architectures/). Each spec module
// default-exports a spec object (see compose.mjs). Outputs land NEXT TO their spec
// (<dir>/<name>.svg and <name>.png), so a diagram's spec and renders always sit together
// in the same folder.

import { readdirSync, existsSync, writeFileSync, mkdirSync } from 'node:fs';
import { join, dirname, resolve, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { composeSVG } from './compose.mjs';
import { withPage, renderSVG } from './raster.mjs';

const HERE = dirname(fileURLToPath(import.meta.url));            // figure/build
const DIAGRAMS = join(HERE, '..', 'diagrams');
const SCALE = 2;                                                // figures are already large

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

await withPage(async (page) => {
  for (const specPath of specs) {
    const mod = await import(pathToFileURL(specPath).href);
    const spec = mod.default;
    const name = spec.name || basename(specPath).replace(/\.fig\.mjs$/, '');
    const outDir = dirname(specPath);                          // outputs sit beside the spec
    mkdirSync(outDir, { recursive: true });
    const svg = composeSVG(spec);
    writeFileSync(join(outDir, `${name}.svg`), svg + '\n');
    const png = await renderSVG(page, svg, SCALE);
    writeFileSync(join(outDir, `${name}.png`), png);
    console.log('built', name, '->', `${name}.svg`, '+', `${name}.png`);
  }
});
