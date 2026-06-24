#!/usr/bin/env bash
# Image Generation Extension - Smoke Test
#
# This is a pi *extension* (not a CLI skill), so tests cover:
#   1. File structure + doc presence
#   2. Extension loads in pi (jiti compiles, pi imports resolve)
#   3. Proxy reachable + pollinations model list
#   4. Credentials resolvable
#   5. Both backends generate images (live, resilient)
#   6. chafa ASCII fallback works (the herdr/multiplexer display fix)
#
# Live network tests are RESILIENT -- they warn, not fail, on flakiness
# (matching the repo convention from fetch-url / web-search tests).
set -e

cd "$(dirname "${BASH_SOURCE[0]}")/../../extensions"

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

# Like assert, but a network-dependent check that should not fail the suite.
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

echo "=== Testing imagegen extension ==="
echo ""

# Resolve proxy URL the same way the extension does
PROXY_BASE="${UNIINFER_PROXY_URL:-https://amd1.mooo.com:8123/v1}"
PROXY_BASE="${PROXY_BASE%/}"

# === 1. File structure ===============================================
echo "[1] File structure..."
assert "imagegen.ts exists"       "[ -f imagegen.ts ]"
assert "imagegen.md doc exists"   "[ -f imagegen.md ]"
assert "registers generate_image" "grep -q 'name: \"generate_image\"' imagegen.ts"
assert "uses provider@modelid"    "grep -q 'splitProviderModel' imagegen.ts"
assert "has ASCII fallback"       "grep -q 'canRenderInline' imagegen.ts"
assert "detects herdr mux"        "grep -q 'HERDR_PANE_ID' imagegen.ts"
assert "chafa --format symbols"   "grep -q -- '--format symbols' imagegen.ts"
echo ""

# === 2. pi loads the extension =======================================
echo "[2] Extension loads in pi..."
# Print mode + trivial prompt. If the extension fails to compile/import,
# pi prints a load error mentioning the file path.
pi -e ./imagegen.ts -p "say hi" >"$TMP/load.out" 2>&1 || true
assert_soft "pi loads imagegen.ts (no parse error)" \
    "grep -qi 'hi' $TMP/load.out && ! grep -qiE 'Failed to load extension|ParseError|cannot find module' $TMP/load.out"
echo ""

# === 3. Proxy reachability ===========================================
echo "[3] Proxy reachable..."
MODELS_HTTP=$(curl -s -m 10 -o /dev/null -w "%{http_code}" "$PROXY_BASE/image/models/pollinations" 2>/dev/null || echo "000")
assert_soft "proxy models endpoint responds" "[ \"$MODELS_HTTP\" = \"200\" ]"

if [ "$MODELS_HTTP" = "200" ]; then
    curl -s -m 10 "$PROXY_BASE/image/models/pollinations" -o "$TMP/models.json" 2>/dev/null
    assert_soft "pollinations returns flux"    "grep -q '\"flux\"' $TMP/models.json"
    assert_soft "pollinations returns kontext" "grep -q '\"kontext\"' $TMP/models.json"
fi
echo ""

# === 4. Credentials ==================================================
echo "[4] Credentials resolvable..."
POLL_KEY=""
TU_KEY=""
command -v credgoo &>/dev/null && POLL_KEY=$(credgoo pollinations 2>/dev/null || true)
command -v credgoo &>/dev/null && TU_KEY=$(credgoo tu 2>/dev/null || true)
[ -n "$POLLINATIONS_API_KEY" ] && POLL_KEY="$POLLINATIONS_API_KEY"
[ -n "$TU_API_KEY" ] && TU_KEY="$TU_API_KEY"
assert_soft "pollinations key resolvable" "[ -n \"\$POLL_KEY\" ]"
assert_soft "tu key resolvable"           "[ -n \"\$TU_KEY\" ]"
echo ""

# === 5. Live generation: pollinations@flux ===========================
echo "[5] Generate via pollinations@flux (fast)..."
if [ -n "$POLL_KEY" ]; then
    curl -s -m 90 -X POST "$PROXY_BASE/images/generations" \
        -H "Content-Type: application/json" -H "Authorization: Bearer $POLL_KEY" \
        -d '{"model":"pollinations@flux","prompt":"a small red cube on white background","size":"512x512"}' \
        -o "$TMP/poll.json" 2>/dev/null || true
    if python3 -c "import json,sys; d=json.load(open('$TMP/poll.json')); assert d['data'][0]['b64_json']" 2>/dev/null; then
        PASS=$((PASS + 1))
        echo "  ok: pollinations returned a b64 image"
        python3 -c "import json,base64; d=json.load(open('$TMP/poll.json')); open('$TMP/poll.png','wb').write(base64.b64decode(d['data'][0]['b64_json']))" 2>/dev/null
    else
        WARN=$((WARN + 1))
        echo "  WARN: pollinations@flux returned no image (network/rate limit?)"
    fi
else
    WARN=$((WARN + 1))
    echo "  WARN: no pollinations key, skipped"
fi
echo ""

# === 6. Live generation: tu@z-image-turbo ============================
echo "[6] Generate via tu@z-image-turbo (quality)..."
if [ -n "$TU_KEY" ]; then
    curl -s -m 150 -X POST "$PROXY_BASE/images/generations" \
        -H "Content-Type: application/json" -H "Authorization: Bearer $TU_KEY" \
        -d '{"model":"tu@z-image-turbo","prompt":"a small red cube on white background","size":"1024x1024"}' \
        -o "$TMP/tu.json" 2>/dev/null || true
    if python3 -c "import json,sys; d=json.load(open('$TMP/tu.json')); assert d['data'][0]['b64_json']" 2>/dev/null; then
        PASS=$((PASS + 1))
        echo "  ok: tu@z-image-turbo returned a b64 image"
        python3 -c "import json,base64; d=json.load(open('$TMP/tu.json')); open('$TMP/tu.png','wb').write(base64.b64decode(d['data'][0]['b64_json']))" 2>/dev/null
    else
        WARN=$((WARN + 1))
        echo "  WARN: tu@z-image-turbo returned no image (network/slow?)"
    fi
else
    WARN=$((WARN + 1))
    echo "  WARN: no tu key, skipped"
fi
echo ""

# === 7. chafa ASCII fallback =========================================
echo "[7] chafa ASCII fallback..."
if command -v chafa &>/dev/null; then
    assert "chafa installed" "true"
    if [ -f "$TMP/poll.png" ]; then
        chafa --format symbols --symbols ascii -c none --work 5 --size 48x16 "$TMP/poll.png" >"$TMP/ascii.txt" 2>/dev/null || true
        assert "chafa produces ASCII output"      "[ -s $TMP/ascii.txt ]"
        assert "ASCII is plain text (no graphics escapes)" "! grep -qE $'\x1b\\\[?_G' $TMP/ascii.txt"
    else
        WARN=$((WARN + 1))
        echo "  WARN: no image to ASCII-render (generation failed above)"
    fi
else
    FAIL=$((FAIL + 1))
    echo "  FAIL: chafa not installed (brew install chafa)"
fi
echo ""

# === Summary =========================================================
echo "============================================"
echo "  PASS: $PASS"
echo "  WARN: $WARN  (resilient network checks)"
echo "  FAIL: $FAIL"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
