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
# Version drift check — derived, not hardcoded: the extension's VERSION const and the
# newest "xmodel X.Y.Z" entry in release-notes.md must agree. A bump that edits only one
# side fails here instead of shipping two sources of truth.
RN_VER=$(grep -oE 'xmodel [0-9]+\.[0-9]+\.[0-9]+' "$REPO/release-notes.md" 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
TS_VER=$(grep -oE 'VERSION = "[0-9]+\.[0-9]+\.[0-9]+"' xmodel.ts | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
assert "version matches release-notes (${TS_VER:-none} vs ${RN_VER:-none})" \
    "[ -n '$RN_VER' ] && [ '$TS_VER' = '$RN_VER' ]"
assert "xmodel-view display entry registered"  "grep -q 'XMODEL_VIEW_MSG = \"xmodel-view\"' xmodel.ts"
assert "message renderer registered"           "grep -q 'registerMessageRenderer' xmodel.ts"
assert "understand param handled"              "grep -q 'understandRaw === true' xmodel.ts"
assert "read protocol note in system prompt"   "grep -q 'READ_PROTOCOL' xmodel.ts"
assert "read intercepted before vision return" "grep -q 'READ HANDOVER' xmodel.ts"
assert "delegate handover wired"               "grep -q 'delegateVision(ctx, event, images' xmodel.ts"
assert "read_image per-call thinking override"  "grep -q 'wantThink' xmodel.ts && grep -q 'thinkingLevel: thinkLevel' xmodel.ts"
assert "understand accepts focus string"        "grep -q 'understandRaw' xmodel.ts"
assert "delegate skips compressor on focus"     "grep -q 'opts.focus' xmodel.ts"
assert "chafa shared module"                "[ -f lib/chafa.ts ]"
assert "chafa result contract (union)"       "grep -q 'ChafaResult' lib/chafa.ts"
assert "no speculative size params"          "grep -q 'chafaPreview(imgPath: string): Promise<ChafaResult>' lib/chafa.ts"
assert "read_image accepts url"              "grep -q 'url: Type.Optional' xmodel.ts"
assert "url download helper"                 "grep -q 'downloadImage' xmodel.ts"
assert "xmodel uses shared chafa"           "grep -q 'lib/chafa' xmodel.ts"
assert "ascii fallback wired into entry"    "grep -q 'details.ascii = arts' xmodel.ts"
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

    # fake failing curl (deterministic throway failure), repo NODE_PATH for imports.
    TMPHOME="$TMP/home"
    mkdir -p "$TMPHOME/.pi/agent" "$TMP/bin"
    printf '#!/bin/sh\nexit 1\n' > "$TMP/bin/curl"
    chmod +x "$TMP/bin/curl"
    # fake pi: runChildPi (delegate brief + VLM sub-calls) spawns `pi --mode json -p`;
    # the stub answers deterministically with one assistant message_end — no network,
    # no real model, fast. Matrix section (f) drives the delegate path through it.
    # Stateful modes via $FAKE_PI_STATE (only affect VLM calls — argv carries the vlm
    # model id + an @image arg; compressor calls stay honest):
    #   timeout_once    first VLM call sleeps past the timeout (transient API hang),
    #                   later calls answer "retry recovered"
    #   always_timeout  every VLM call sleeps — both attempts die (final TIMED OUT)
    # Section (g) drives the retry-on-timeout contract through it.
    cat > "$TMP/bin/pi" <<'STUB'
#!/bin/sh
is_vlm=0; has_img=0
for a in "$@"; do
    [ "$a" = "test/vlm-model" ] && is_vlm=1
    case "$a" in @*) has_img=1 ;; esac
done
state=""
[ -n "$FAKE_PI_STATE" ] && [ -f "$FAKE_PI_STATE" ] && state=$(cat "$FAKE_PI_STATE")
if [ "$is_vlm" = 1 ] && [ "$has_img" = 1 ]; then
    case "$state" in
        timeout_once)
            n=$(cat "$FAKE_PI_STATE.n" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$FAKE_PI_STATE.n"
            [ "$n" -le 1 ] && exec sleep 30
            printf '%s\n' '{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"retry recovered: VLM answered on the second attempt"}]}}'
            exit 0
            ;;
        always_timeout)
            exec sleep 30
            ;;
    esac
fi
cat <<'JSON'
{"type":"message_end","message":{"role":"assistant","content":[{"type":"text","text":"fake analysis"}]}}
JSON
STUB
    chmod +x "$TMP/bin/pi"

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
        MATRIX_OUT=$(cd "$REPO" && HOME="$TMPHOME" PATH="$TMP/bin:$PATH" JITI_DIR="$JITI_DIR" XMODEL_VLM_TIMEOUT_MS=1500 \
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

# === 3. display path normalises non-PNG to PNG ======================
# toDisplayPng transcodes via photon (pi's bundled WASM) and caps the long
# edge at 1200px — the format bug itself is fixed upstream since pi 1.0.1
# (pi#10292); our path stays for the resize. photon resolves from pi's
# entry, and argv[1] here is node, so PI_PHOTON_ENTRY points the resolver
# at pi's real cli.js. Fixtures are COMMITTED (the old sips-based runtime
# generation failed without desktop pictures and could not encode webp at
# all — it also silently masked a non-resolving photon).
echo "[3] Display path normalises non-PNG to PNG..."
if [ ! -x "$TSC" ]; then
    WARN=$((WARN + 1))
    echo "  WARN: tsc not found (run scripts/lint.sh once) — skipped"
elif [ ! -f "$HERE/fixtures/t-small.jpg" ]; then
    WARN=$((WARN + 1))
    echo "  WARN: committed fixtures missing — skipped"
elif ! command -v pi >/dev/null 2>&1; then
    WARN=$((WARN + 1))
    echo "  WARN: pi not on PATH (photon entry unresolvable) — skipped"
else
    # Compile to CommonJS like section 2 — raw node cannot import the .ts
    # sources (extensionless ./image-normalize specifier; strip-types needs .ts).
    if ! "$TSC" "$EXT/lib/image-utils.ts" --outDir "$TMP/js3" --module commonjs --moduleResolution node \
        --target ES2022 --strict --esModuleInterop --skipLibCheck --types node >"$TMP/tsc3.out" 2>&1; then
        FAIL=$((FAIL + 1))
        echo "  FAIL: tsc compile error"; sed 's/^/    /' "$TMP/tsc3.out" | head -10
    else
        UT="$TMP/todisplaypng.cjs"
        cat >"$UT" <<'UTEOF'
const { toDisplayPng, isPng } = require("JSDIR/image-utils.js");
const { normalizationProbe } = require("JSDIR/image-normalize.js");
const { readFileSync } = require("node:fs");

// 77 = photon unresolvable under PI_PHOTON_ENTRY → honest WARN skip, not FAIL.
if (!normalizationProbe().available) { console.log("PHOTON-UNAVAILABLE"); process.exit(77); }

const files = process.argv.slice(2);
if (!files.length) { console.error("no fixture files given"); process.exit(1); }
let bad = 0;
for (const f of files) {
    const b64 = readFileSync(f).toString("base64");
    const out = toDisplayPng(b64);
    if (!isPng(Buffer.from(out, "base64"))) {
        console.log(`NOTPNG ${f}`);
        bad++;
    }
}
// A PNG input must survive untouched (no re-encode, no size drift).
const png = files.find((f) => f.endsWith(".png"));
if (png) {
    const b64 = readFileSync(png).toString("base64");
    if (toDisplayPng(b64) !== b64) { console.log("REENCODED-PNG"); bad++; }
}
process.exit(bad ? 1 : 0);
UTEOF
        sed -i.bak "s|JSDIR|$TMP/js3|" "$UT" && rm -f "$UT.bak"

        FX="$HERE/fixtures/t-small.png $HERE/fixtures/t-small.jpg $HERE/fixtures/t-small.gif $HERE/fixtures/t-small.webp"
        PI_PHOTON_ENTRY="$(realpath "$(command -v pi)")" node "$UT" $FX >"$TMP/ut.out" 2>&1
        rc=$?
        if [ "$rc" -eq 77 ]; then
            WARN=$((WARN + 1))
            echo "  WARN: photon not resolvable via PI_PHOTON_ENTRY — skipped"
        elif [ "$rc" -eq 0 ]; then
            PASS=$((PASS + 1))
            echo "  ok: png/jpg/gif/webp all normalise to PNG (png byte-identical, photon path)"
        else
            FAIL=$((FAIL + 1))
            echo "  FAIL: non-PNG not normalised to PNG"
            sed 's/^/    /' "$TMP/ut.out" | head -8
        fi
    fi
fi
echo ""

# === 4. pi loads the extension ======================================
echo "[4] Extension loads in pi..."
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
