#!/usr/bin/env bash
# xmodel Extension — v0.5.1 read-handover routing matrix test
#
# This is a pi *extension* (not a CLI skill). Tests cover:
#   1. File structure (handover, understand param, protocol note present)
#   2. THE ROUTING MATRIX — compile xmodel.ts, load it with a mocked
#      ExtensionAPI, fire tool_result events, assert the three-way routing:
#        a. read img, default, non-vision model  -> handover display-only
#        b. read img, understand:true, VISION model -> pass-through (undefined)
#        c. read img, understand:true, non-vision -> delegate fails (no VLM
#           configured) -> handover fallback
#        d. read img, view mode                  -> throway route (fake curl
#           fails offline deterministically -> "could not upload" note)
#   3. pi loads the extension (live, resilient)
#
# No network needed for section 2: HOME is a tempdir (empty config -> default
# delegate mode), PATH gets a fake failing `curl`, the model registry is empty.
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
EXT="$REPO/extensions"

cd "$EXT"

PASS=0
FAIL=0
WARN=0

assert() {
    if eval "$2"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: $1"
    fi
}

assert_soft() {
    if eval "$2"; then
        PASS=$((PASS + 1))
    else
        WARN=$((WARN + 1))
        echo "  WARN: $1 (network/provider flakiness?)"
    fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "=== Testing xmodel extension (read handover v0.5.1) ==="
echo ""

# === 1. File structure ==============================================
echo "[1] File structure..."
assert "xmodel.ts exists"                      "[ -f xmodel.ts ]"
assert "xmodel.md doc exists"                  "[ -f xmodel.md ]"
assert "version bumped to 0.5.1"               "grep -q 'VERSION = \"0.5.1\"' xmodel.ts"
assert "xmodel-view display entry registered"  "grep -q 'XMODEL_VIEW_MSG = \"xmodel-view\"' xmodel.ts"
assert "message renderer registered"           "grep -q 'registerMessageRenderer' xmodel.ts"
assert "understand param handled"              "grep -q 'understand === true' xmodel.ts"
assert "read protocol note in system prompt"   "grep -q 'READ_PROTOCOL' xmodel.ts"
assert "read intercepted before vision return" "grep -q 'READ HANDOVER' xmodel.ts"
assert "delegate handover wired"               "grep -q 'delegateVision(ctx, event, images' xmodel.ts"
assert "read_image per-call thinking override"  "grep -q 'wantThink' xmodel.ts && grep -q 'thinkingLevel: thinkLevel' xmodel.ts"
assert "protocol teaches deep path"             "grep -q \"thinking:'high'\" xmodel.ts"
echo ""

# === 2. Routing matrix (mocked ExtensionAPI, no network) ============
echo "[2] Routing matrix (compile + mock) ..."
TSC="$HOME/.cache/skale-skills/lint/node_modules/.bin/tsc"
if [ ! -x "$TSC" ]; then
    echo "  WARN: tsc not found — run 'bash scripts/lint.sh' once to install the toolchain; skipping matrix"
    WARN=$((WARN + 1))
else
    # Compile xmodel.ts (+ its lib/* imports) to plain CommonJS, mirroring the
    # repo tsconfig flags (lint.sh typechecks with these and passes).
    if "$TSC" xmodel.ts --outDir "$TMP/js" --module commonjs --moduleResolution node \
        --target ES2022 --strict --esModuleInterop --skipLibCheck --types node >"$TMP/tsc.out" 2>&1; then
        PASS=$((PASS + 1))
        echo "  ok: tsc compiled xmodel.ts"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: tsc compile error"; sed 's/^/    /' "$TMP/tsc.out" | head -10
    fi

    # Isolated environment: empty HOME (default delegate mode, no user presets),
    # fake failing curl (deterministic throway failure), repo NODE_PATH for imports.
    TMPHOME="$TMP/home"
    mkdir -p "$TMPHOME/.pi/agent" "$TMP/bin"
    printf '#!/bin/sh\nexit 1\n' > "$TMP/bin/curl"
    chmod +x "$TMP/bin/curl"

    # Locate jiti (the loader pi itself uses for extensions).
    JITI_DIR=""
    for cand in \
        "/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules" \
        "$(npm root -g 2>/dev/null)/@earendil-works/pi-coding-agent/node_modules"; do
        if [ -n "$cand" ] && [ -d "$cand/jiti" ]; then JITI_DIR="$cand"; break; fi
    done
    if [ -z "$JITI_DIR" ]; then
        echo "  WARN: jiti not found (is pi installed?) — skipping matrix"
        WARN=$((WARN + 1))
    elif [ ! -f "$EXT/xmodel.ts" ]; then
        FAIL=$((FAIL + 1))
        echo "  FAIL: extensions/xmodel.ts not found"
    else
        MATRIX_OUT=$(cd "$REPO" && HOME="$TMPHOME" PATH="$TMP/bin:$PATH" JITI_DIR="$JITI_DIR" \
            node "$HERE/xmodel-matrix.mjs" "$EXT/xmodel.ts" 2>&1) || true
        echo "$MATRIX_OUT" | sed 's/^/    /'
        OK_COUNT=$(echo "$MATRIX_OUT" | grep -c '^CHECK .*: ok$' || true)
        BAD_COUNT=$(echo "$MATRIX_OUT" | grep -c '^CHECK .*: FAIL$' || true)
        PASS=$((PASS + OK_COUNT))
        FAIL=$((FAIL + BAD_COUNT))
        if [ "$OK_COUNT" -eq 0 ] && [ "$BAD_COUNT" -eq 0 ]; then
            FAIL=$((FAIL + 1))
            echo "  FAIL: matrix produced no CHECK lines (loader crash?)"
        fi
    fi
fi
echo ""

# === 3. pi loads the extension ======================================
echo "[3] Extension loads in pi..."
if command -v pi >/dev/null 2>&1; then
    # --no-extensions: the installed package copy also registers switch_model/read_image;
    # loading the repo copy on top would CONFLICT (duplicate tool names), so isolate it.
    pi --no-extensions -e ./xmodel.ts -p "say hi" >"$TMP/load.out" 2>&1 || true
    assert_soft "pi loads xmodel.ts (no parse error)" \
        "! grep -qiE 'Failed to load extension|ParseError|cannot find module|conflicts with' $TMP/load.out"
else
    WARN=$((WARN + 1))
    echo "  WARN: pi not on PATH, skipped"
fi
echo ""

echo "──────────────────────────────"
echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
if [ "$FAIL" -ne 0 ]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
