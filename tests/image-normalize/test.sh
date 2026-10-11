#!/usr/bin/env bash
# tests/image-normalize/test.sh — portable image normalisation (photon-WASM) for the vision path.
#
# Contract under test (extensions/lib/image-normalize.ts):
#   1. photon resolves from pi's own entry (process.argv[1]) — the portability seam
#   2. oversized images are aspect-preserving DOWNSCALED to the ceilings
#   3. small images are returned as null (never upscaled, never touched)
#   4. EXIF orientation is honoured (a rotated 6/8 image comes back upright)
#   5. failure degrades to null (caller keeps the original bytes)
#   6. non-PNG input (JPEG) decodes and re-encodes
#   7. the ceilings are env-overridable; 0 disables a ceiling
#
# No network, no OS tools (no sips/ImageMagick) — that is the whole point.
set -u
REPO="$(cd "$(dirname "$0")/../../.." && pwd)"
# The harness may run from a symlinked checkout — resolve to the real repo root.
if [ ! -f "$REPO/extensions/lib/image-normalize.ts" ]; then
    REPO="$(cd "$(dirname "$0")/../.." && pwd)"
fi
TMP="${TMPDIR:-/tmp}/image-normalize-test"
rm -rf "$TMP"; mkdir -p "$TMP"
PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS+1)); echo "  CHECK $1: ok"; }
bad()  { FAIL=$((FAIL+1)); echo "  CHECK $1: FAIL"; }
warn() { WARN=$((WARN+1)); echo "  CHECK $1: WARN (${2:-})"; }
check(){ if [ "${2:-0}" = "1" ]; then ok "$1"; else bad "$1"; fi; }

echo "[1] Compile the lib with the repo toolchain ..."
TSC="$HOME/.cache/skale-skills/lint/node_modules/.bin/tsc"
OUT="$TMP/build"
mkdir -p "$OUT"
if [ -x "$TSC" ]; then
    if "$TSC" "$REPO/extensions/lib/image-normalize.ts" --outDir "$OUT" \
        --module esnext --target es2022 --moduleResolution bundler --skipLibCheck >"$TMP/tsc.out" 2>&1; then
        ok "tsc compiled image-normalize.ts"
    else
        bad "tsc compile error"; sed 's/^/    /' "$TMP/tsc.out" | head -10
        echo "RESULT: FAIL"; exit 1
    fi
else
    warn "tsc not found — run 'bash scripts/lint.sh' once to install the toolchain" "skipping"
    echo "RESULT: PASS (with warnings)"; exit 0
fi

echo "[2] Real-image behaviour (needs pi's bundled photon) ..."
# pi's bundled photon resolves from pi's own entry file. We must NOT launch pi
# (it would open a session); instead we run plain node and hand the probe a
# shim that sets argv[1] to pi's cli.js — the same seam the lib uses at runtime.
PI_CLI="/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js"
if [ ! -f "$PI_CLI" ]; then
    # Linux/Windows: readlink -f $(which pi); if that fails, the probe runs in
    # degraded mode (argv[1] points at /tmp) and reports WARN — honest skip.
    PI_BIN="$(command -v pi 2>/dev/null || true)"
    PI_CLI="$([ -n "$PI_BIN" ] && readlink -f "$PI_BIN" 2>/dev/null || echo /tmp)"
fi

# Run a probe script with argv[1] set to pi's entry so photon resolves.
run_probe() {
    node "$REPO/tests/image-normalize/run-with-pi-entry.mjs" "$1" "$2" "${3:-}" "${4:-}"
}

# Build fixtures with photon itself (a 1430x2275 PNG like the incident screenshot,
# a small 200x100 PNG, and JPEGs) so the test is deterministic and offline.
FIX="$TMP/fixtures"; mkdir -p "$FIX"
run_probe "$PI_CLI" "$REPO/tests/image-normalize/make-fixtures.mjs" "$FIX" >"$TMP/fix.out" 2>&1
if [ -s "$FIX/big.png" ] && [ -s "$FIX/small.png" ] && [ -s "$FIX/photo.jpg" ]; then
    ok "fixtures built (big/small/jpeg)"
else
    bad "fixture build failed"; sed 's/^/    /' "$TMP/fix.out" | head -5
    echo "RESULT: FAIL"; exit 1
fi

run_probe "$PI_CLI" "$REPO/tests/image-normalize/probe.mjs" "$OUT/image-normalize.js" "$FIX" 2>&1 | tee "$TMP/probe.out"
while IFS= read -r line; do
    case "$line" in
        "ok "*) ok "${line#ok }" ;;
        "FAIL "*) bad "${line#FAIL }" ;;
        "warn "*) warn "${line#warn }" ;;
    esac
done < "$TMP/probe.out"

echo "[3] Degraded mode (photon unavailable) → null, never a throw ..."
# Simulate a machine where photon cannot be resolved: argv[1] points at a file
# outside any node_modules chain.
run_probe "/tmp" "$REPO/tests/image-normalize/probe.mjs" "$OUT/image-normalize.js" "$FIX" 2>&1 | tee "$TMP/probe2.out"
while IFS= read -r line; do
    case "$line" in
        "ok "*) ok "${line#ok }" ;;
        "FAIL "*) bad "${line#FAIL }" ;;
        "warn "*) warn "${line#warn }" ;;
    esac
done < "$TMP/probe2.out"

echo
echo "──────────────────────────"
echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
if [ "$FAIL" -eq 0 ]; then echo "RESULT: PASS"; else echo "RESULT: FAIL"; fi
rm -rf "$TMP"
[ "$FAIL" -eq 0 ]
