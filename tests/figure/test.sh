#!/usr/bin/env bash
# Figure skill test suite.
# Gate 1 — layout() unit tests (node:test): geometry resolution is correct.
# Gate 2 — review_figure on every example spec: bounds + collisions clean.
# Gate 3 — composeSVG produces a non-empty, well-formed SVG for every example.
set -e

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/figure"
FIG_DIR="$(pwd)"

PASS=0
FAIL=0
assert() {
    if eval "$2"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: $1"
    fi
}

echo "=== Testing figure skill ==="
echo ""

# ── 1. layout() unit tests ──────────────────────────────────────────────
echo "[1] layout() unit tests (node:test)..."
assert "layout unit tests pass" "node --test build/layout.test.mjs >/tmp/fig-layout-test.log 2>&1"
echo ""

# ── 2. every example spec lints clean (bounds + collisions) ─────────────
echo "[2] review_figure on example specs..."
for spec in diagrams/examples/*/*.fig.mjs; do
    name="$(basename "$(dirname "$spec")")"
    assert "review clean: $name" "node build/review_figure.mjs '$spec' >/tmp/fig-review-$name.log 2>&1"
done
echo ""

# ── 3. composeSVG emits a valid SVG for every example ───────────────────
echo "[3] composeSVG emits well-formed SVG..."
for spec in diagrams/examples/*/*.fig.mjs; do
    name="$(basename "$(dirname "$spec")")"
    assert "composes to <svg>: $name" "node --input-type=module -e \"
        import { composeSVG } from './build/compose.mjs';
        import { pathToFileURL } from 'node:url';
        const m = await import(pathToFileURL('$spec').href);
        const svg = composeSVG(m.default);
        if (!svg.startsWith('<svg') || !svg.includes('</svg>')) process.exit(1);
        if (svg.length < 500) process.exit(1);\" >/dev/null 2>&1"
done
echo ""

echo "==============================="
echo "PASS: $PASS  FAIL: $FAIL"
if [ "$FAIL" -ne 0 ]; then exit 1; fi
echo "All figure tests passed."
