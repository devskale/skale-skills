#!/usr/bin/env bash
# Image Generation Extension - Smoke Test
#
# This is a pi *extension* (not a CLI skill), so tests cover:
#   1. File structure + doc presence
#   2. Extension loads in pi (jiti compiles, pi imports resolve)
#   3. Proxy reachable + pollinations model list
#   4. Credentials resolvable
#   5. Both backends generate images (live, resilient)
#   6. chafa ASCII fallback works (the multiplexer display fix, tmux/screen)
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
PROXY_BASE="${UNIINFER_PROXY_URL:-https://uniinfer.skale.dev/v1}"
PROXY_BASE="${PROXY_BASE%/}"

# === 1. File structure ===============================================
echo "[1] File structure..."
assert "imagegen.ts exists"       "[ -f imagegen.ts ]"
assert "imagegen.md doc exists"   "[ -f imagegen.md ]"
assert "registers generate_image" "grep -q 'name: \"generate_image\"' imagegen.ts"
assert "uses provider@modelid"    "grep -q 'splitProviderModel' imagegen.ts"
assert "probes per-provider image models" "grep -q '/image/models/' imagegen.ts"
assert "detects model-unavailable errors" "grep -q 'isModelUnavailable' imagegen.ts"
assert "no hardcoded model list"   "! grep -qE 'dreamshaper|z-image-turbo|flux' <(grep -A5 'imageModelsForProvider' imagegen.ts)"
assert "has ASCII fallback"       "grep -q 'canRenderInline' imagegen.ts"
assert "detects tmux/screen mux"  "grep -q 'process.env.TMUX || process.env.SCREEN' imagegen.ts"
assert "herdr NOT treated as mux" "! grep -q 'HERDR_PANE_ID' imagegen.ts"
assert "chafa --format symbols"   "grep -q -- '--format symbols' lib/chafa.ts"
assert "imagegen uses shared chafa"  "grep -q 'lib/chafa' imagegen.ts"
echo ""

# === 2. pi loads the extension =======================================
echo "[2] Extension loads in pi..."
# Print mode + trivial prompt. If the extension fails to compile/import,
# pi prints a load error mentioning the file path.
# --no-extensions: the installed package copy also registers generate_image;
# loading the repo copy on top CONFLICTS (duplicate tool name) — same
# isolation the xmodel suite needed (its 2026-10 retro).
pi --no-extensions -e ./imagegen.ts -p "say hi" >"$TMP/load.out" 2>&1 || true
assert_soft "pi loads imagegen.ts (no parse error)" \
    "grep -qi 'hi' $TMP/load.out && ! grep -qiE 'Failed to load extension|ParseError|cannot find module' $TMP/load.out"
echo ""

# === 3. Proxy reachability ===========================================
echo "[3] Proxy reachable..."
MODELS_HTTP=$(curl -s -m 10 -o /dev/null -w "%{http_code}" "$PROXY_BASE/image/models/pollinations" 2>/dev/null || echo "000")
assert_soft "proxy models endpoint responds" "[ \"$MODELS_HTTP\" = \"200\" ]"

if [ "$MODELS_HTTP" = "200" ]; then
    curl -s -m 10 "$PROXY_BASE/image/models/pollinations" -o "$TMP/models.json" 2>/dev/null
    # Substring, nicht '"id"' mit Quotes: der Katalog ist namespaced worden
    # (2026-10-17: 'lykon/dreamshaper-8-lcm', 'flux.1-kontext-pro' — die alten
    # 'pollinations@dreamshaper'-IDs gibt es nicht mehr). Wir prüfen, dass die
    # FAMILIE noch gelistet ist, nicht die exakte alte Schreibweise.
    assert_soft "pollinations returns dreamshaper"    "grep -q dreamshaper $TMP/models.json"
    assert_soft "pollinations returns kontext" "grep -q kontext $TMP/models.json"
fi
echo ""

# === 4. Credentials ==================================================
echo "[4] Credentials resolvable..."
# One gateway, one token: credgoo service `unii` (or UNIINFER_API_KEY),
# with per-provider env overrides for scoped tokens. The per-provider credgoo
# services (pollinations, tu) were REMOVED 2026-10-17 — they shadowed the
# valid gateway token with stale sk_-style keys.
UNII_KEY=""
command -v credgoo &>/dev/null && UNII_KEY=$(credgoo unii 2>/dev/null || true)
[ -n "$UNIINFER_API_KEY" ] && UNII_KEY="$UNIINFER_API_KEY"
POLL_KEY="${POLLINATIONS_API_KEY:-$UNII_KEY}"
TU_KEY="${TU_API_KEY:-$UNII_KEY}"
assert_soft "unii gateway key resolvable (credgoo unii / UNIINFER_API_KEY)" "[ -n \"\$UNII_KEY\" ]"
echo ""

# === 5. Live generation: pollinations@lykon/dreamshaper-8-lcm =========
echo "[5] Generate via pollinations@lykon/dreamshaper-8-lcm (cheap)..."
if [ -n "$POLL_KEY" ]; then
    curl -s -m 90 -X POST "$PROXY_BASE/images/generations" \
        -H "Content-Type: application/json" -H "Authorization: Bearer $POLL_KEY" \
        -d '{"model":"pollinations@lykon/dreamshaper-8-lcm","prompt":"a small red cube on white background","size":"512x512"}' \
        -o "$TMP/poll.json" 2>/dev/null || true
    if python3 -c "import json,sys; d=json.load(open('$TMP/poll.json')); assert d['data'][0]['b64_json']" 2>/dev/null; then
        PASS=$((PASS + 1))
        echo "  ok: pollinations returned a b64 image"
        python3 -c "import json,base64; d=json.load(open('$TMP/poll.json')); open('$TMP/poll.png','wb').write(base64.b64decode(d['data'][0]['b64_json']))" 2>/dev/null
    else
        WARN=$((WARN + 1))
        echo "  WARN: pollinations@lykon/dreamshaper-8-lcm returned no image (network/rate limit?)"
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
    WARN=$((WARN + 1))
    echo "  WARN: chafa not installed (brew install chafa) — skipping ASCII fallback check"
fi
echo ""

# === 8. Offline integration: auth-rejection + success via mock relay =======
# Pinned 2026-10-17 (the revoked-token incident): a 401 "Unknown or revoked
# token" must NOT terminate the call bare (old behavior) — it skips catalog
# probing, fires the emergency pollinations-free path, and surfaces a rotation
# hint when that also fails. With network up the emergency may genuinely
# SUCCEED (pollinations direct is free+keyless) — both outcomes pin the new
# path; the old code (terminal 401, no emergency, no hint) fails this either way.
# The success leg is fully offline-deterministic: valid token against the same
# mock must write the file and embed the prompt as PNG metadata.
# Two separate node processes: the gateway key is memoized per session/process
# (by design), so the key swap dead→good must cross a process boundary.
echo "[8] Offline integration: mock relay (auth-rejection + success)..."
TSC="$HOME/.cache/skale-skills/lint/node_modules/.bin/tsc"
if [ ! -x "$TSC" ]; then
    WARN=$((WARN + 1))
    echo "  WARN: tsc not found (run scripts/lint.sh once) — skipped"
elif ! command -v pi >/dev/null 2>&1; then
    WARN=$((WARN + 1))
    echo "  WARN: pi not on PATH (node_modules resolution) — skipped"
else
    if ! "$TSC" imagegen.ts --outDir "$TMP/js8" --module commonjs --moduleResolution node \
        --target ES2022 --strict --esModuleInterop --skipLibCheck --types node >"$TMP/tsc8.out" 2>&1; then
        FAIL=$((FAIL + 1))
        echo "  FAIL: tsc compile error"; sed 's/^/    /' "$TMP/tsc8.out" | head -8
    else
        # pi's bundled node_modules (require('@earendil-works/pi-tui') etc.)
        PI_REAL="$(realpath "$(command -v pi)")"
        while [ "$PI_REAL" != "/" ] && [ ! -d "$(dirname "$PI_REAL")/node_modules" ]; do
            PI_REAL="$(dirname "$PI_REAL")"
        done
        PI_NODE_MODULES="$(dirname "$PI_REAL")/node_modules"

        # Mock relay: 401-revoked unless Bearer sk-test-good → tiny PNG.
        MOCKPY="$TMP/mock.py"
        cat >"$MOCKPY" <<'MEOF'
import http.server, json, sys
PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
class H(http.server.BaseHTTPRequestHandler):
    def _serve(self):
        good = self.headers.get("Authorization") == "Bearer sk-test-good"
        body = json.dumps({"data": [{"b64_json": PNG}]} if good else
                          {"detail": "Unknown or revoked token. Request a current token from the operator."}).encode()
        self.send_response(200 if good else 401)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def do_GET(self): self._serve()
    def do_POST(self):
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        self._serve()
    def log_message(self, *a): pass
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
print(srv.server_address[1], flush=True)
srv.serve_forever()
MEOF
        python3 "$MOCKPY" >"$TMP/mock.port" 2>/dev/null &
        MPID=$!
        for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$TMP/mock.port" ] && break; sleep 0.3; done
        MPORT="$(cat "$TMP/mock.port" 2>/dev/null)"

        UT="$TMP/mockgen.cjs"
        cat >"$UT" <<'UTEOF'
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");

// Hermetic HOME: fake auth.json; credgoo resolves via $HOME/.local/bin which
// does not exist in this sandbox — resolution falls through to auth.json.
const keyMode = process.argv[2] === "good" ? "sk-test-good" : "sk-test-dead";
const home = fs.mkdtempSync(path.join(os.tmpdir(), "imgen-home-"));
fs.mkdirSync(path.join(home, ".pi", "agent"), { recursive: true });
fs.writeFileSync(path.join(home, ".pi", "agent", "auth.json"),
  JSON.stringify({ unii: { type: "api_key", key: keyMode } }));
process.env.HOME = home;
delete process.env.UNIINFER_API_KEY;
process.env.UNIINFER_PROXY_URL = `http://127.0.0.1:${process.argv[3]}/v1`;

const { generateAndSave, isAuthRejected } = require("JSDIR/imagegen.js");
const cwd = fs.mkdtempSync(path.join(os.tmpdir(), "imgen-out-"));

(async () => {
    let bad = 0;
    // Classifier pin (deterministic, offline): the exact incident error string.
    const incident = 'proxy returned 401 Unauthorized — {"detail": "Unknown or revoked token. Request a current token from the operator."}';
    const pin = isAuthRejected(incident) && !isAuthRejected("proxy returned 402 — costs ~0.0020 pollen")
              && !isAuthRejected("proxy returned 500 Internal Server Error");
    console.log(`classifier-pin: ${pin}`);
    if (!pin) bad++;

    if (keyMode === "sk-test-dead") {
        // Auth-rejection path: emergency fires (may SUCCEED with network — fine);
        // a rotation hint must appear whenever it fails. Old code failed BOTH.
        const r = await generateAndSave({ prompt: "a tiny red cube", model: "tu@z-image-turbo", size: "64x64", cwd });
        const okViaEmergency = r.ok === true;
        const hinted = r.ok !== true && /rotate the gateway token/.test(r.suggested || "");
        console.log(`auth-path: ok=${r.ok} hinted=${hinted}`);
        if (!okViaEmergency && !hinted) bad++;
    } else {
        // Success path (offline-deterministic): file written + prompt embedded.
        const r = await generateAndSave({ prompt: "a tiny blue cube", model: "tu@z-image-turbo", size: "64x64", cwd });
        const wrote = r.ok && fs.existsSync(r.saved[0].path);
        const metaOk = wrote && fs.readFileSync(r.saved[0].path).includes(Buffer.from("a tiny blue cube"));
        console.log(`ok-path: ok=${r.ok} wrote=${wrote} meta=${metaOk}`);
        if (!r.ok || !wrote || !metaOk) bad++;
    }
    process.exit(bad ? 1 : 0);
})().catch((e) => { console.error(String(e)); process.exit(1); });
UTEOF
        sed -i.bak -e "s|JSDIR|$TMP/js8|" "$UT" && rm -f "$UT.bak"

        # set -e safety: every node exit is captured, never fatal to the suite.
        rc_dead=0; rc_good=0
        NODE_PATH="$PI_NODE_MODULES" node "$UT" dead "$MPORT" >"$TMP/ut-dead.out" 2>&1 || rc_dead=$?
        NODE_PATH="$PI_NODE_MODULES" node "$UT" good "$MPORT" >"$TMP/ut-good.out" 2>&1 || rc_good=$?
        kill "$MPID" 2>/dev/null || true
        wait "$MPID" 2>/dev/null || true

        if [ "$rc_dead" -eq 0 ] && [ "$rc_good" -eq 0 ]; then
            PASS=$((PASS + 2))
            echo "  ok: 401-revoked → emergency path + hint (classifier pinned)"
            echo "  ok: valid token → image written + prompt metadata embedded"
        else
            FAIL=$((FAIL + 1))
            echo "  FAIL: mock-relay integration (dead:$rc_dead good:$rc_good)"
            sed 's/^/    /' "$TMP/ut-dead.out" | head -5
            sed 's/^/    /' "$TMP/ut-good.out" | head -5
        fi
    fi
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
