// Shared SVG -> PNG rasterizer for the figure toolchain.
// One code path for both the icon previews (assets/render_pngs.mjs) and composed
// diagrams (build_figures.mjs). Uses `rsvg-convert` (librsvg, Homebrew) — a lightweight
// native rasterizer — instead of a full headless Chromium. No browser download; the
// Patrick Hand house font is embedded as a data: URI in the SVG so text renders
// correctly (never a sans fallback) without any font setup.

import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Resolve the rsvg-convert binary across macOS (Homebrew) and Linux (apt/dnf/path).
// Returns an absolute path or the bare name if found on PATH; null if unavailable.
export function findRsvg() {
  const candidates = [
    // macOS Homebrew (Apple Silicon + Intel)
    '/opt/homebrew/bin/rsvg-convert',
    '/usr/local/bin/rsvg-convert',
    // Linux (librsvg2-bin / librsvg2-tools) + plain PATH fallback
    '/usr/bin/rsvg-convert',
    '/usr/local/bin/rsvg-convert',
    'rsvg-convert',
  ];
  for (const c of candidates) {
    try {
      execFileSync(c, ['--version'], { stdio: 'ignore' });
      return c;
    } catch { /* try next */ }
  }
  return null;
}

export function svgSize(svg) {
  const m = svg.match(/viewBox="([\d.\s-]+)"/);
  if (m) { const [, , w, h] = m[1].trim().split(/\s+/).map(Number); return { w, h }; }
  const w = Number((svg.match(/\bwidth="(\d+)/) || [])[1]) || 120;
  const h = Number((svg.match(/\bheight="(\d+)/) || [])[1]) || 120;
  return { w, h };
}

// Render one SVG string to a transparent PNG buffer at `scale`x.
// Returns a Buffer. rsvg-convert does not write PNG to stdout (-o - yields an empty
// file), so we round-trip through a temp dir. Throws if rsvg-convert is unavailable
// or the render fails.
export function renderSVG(svg, scale = 4) {
  const rsvg = findRsvg();
  if (!rsvg) {
    throw new Error(
      "rsvg-convert not found. Install it: brew install librsvg (macOS) or " +
      "apt install librsvg2-bin / dnf install librsvg2-tools (Linux). " +
      "This replaced the old Playwright/Chromium dependency."
    );
  }
  const dir = mkdtempSync(join(tmpdir(), 'figure-rsvg-'));
  const inSvg = join(dir, 'in.svg');
  const outPng = join(dir, 'out.png');
  try {
    writeFileSync(inSvg, svg);
    execFileSync(rsvg, ['-z', String(scale), '-f', 'png', '-o', outPng, inSvg], {
      stdio: 'pipe',
    });
    return readFileSync(outPng);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
