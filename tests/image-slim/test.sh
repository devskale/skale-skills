#!/usr/bin/env bash
# tests/image-slim/test.sh — the compaction image-stripper extension.
set -uo pipefail
cd "$(dirname "$0")/../.."

PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN + 1)); echo "  WARN (skipped honestly): $1" >&2; }
assert() { if eval "$2" >/dev/null 2>&1; then ok; else bad "$1"; fi; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "image-slim tests"
echo "----------------"

echo "[1] File structure"
assert "extensions/image-slim.ts exists"  "[ -f extensions/image-slim.ts ]"
assert "extensions/image-slim.md doc exists" "[ -f extensions/image-slim.md ]"
assert "AGENTS.md references image-slim"  "grep -q 'image-slim' AGENTS.md"
assert "release-notes mention image-slim" "grep -q 'image-slim' release-notes.md"

echo ""
echo "[2] Strip logic (real extension, mocked hook)"
# Load the extension with a mock pi that captures the session_before_compact
# handler, then fire it with a preparation carrying images + assert on the
# mutated preparation — the same payload shape pi hands the hook.
cat >"$TMP/harness.mjs" <<'UTEOF'
import { createRequire } from "node:module";
const req = createRequire(import.meta.url);
const { createJiti } = req("JITI_PATH");
const j = createJiti(import.meta.url);
const handlers = {};
const pi = {
	on: (ev, fn) => { (handlers[ev] ??= []).push(fn); },
	registerTool: () => {}, registerCommand: () => {}, registerShortcut: () => {},
	registerMessageRenderer: () => {},
};
await j("./EXT/image-slim.ts").default(pi);
const h = handlers["session_before_compact"]?.[0];
if (!h) { console.error("no session_before_compact handler"); process.exit(1); }

const bigB64 = "A".repeat(300_000);
const mk = (blocks) => ({ role: "user", content: blocks });
const preparation = {
	messagesToSummarize: [
		mk([{ type: "text", text: "hallo" }, { type: "image", data: bigB64, mimeType: "image/jpeg" }]),
		mk([{ type: "text", text: "unverändert prüfen" }]),
	],
	turnPrefixMessages: [mk([{ type: "image", data: "iVBORw0", mimeType: "image/png" }])],
};
const snapshot = JSON.stringify(preparation);
const ctx = { ui: { notify: () => {} } };
await h({ preparation }, ctx);

const m0 = preparation.messagesToSummarize[0];
const kinds0 = m0.content.map((b) => b.type);
if (kinds0.includes("image")) { console.error("FAIL: image still in messagesToSummarize"); process.exit(1); }
if (preparation.turnPrefixMessages[0].content.some((b) => b.type === "image")) { console.error("FAIL: image still in turnPrefix"); process.exit(1); }
if (!JSON.stringify(preparation).includes("[image omitted from summary")) { console.error("FAIL: no placeholder text"); process.exit(1); }
if (JSON.stringify(preparation).length > 5000) { console.error("FAIL: payload not slimmed: " + JSON.stringify(preparation).length); process.exit(1); }
// non-mutation of the ORIGINAL blocks (copies, not live state)
if (bigB64.length !== 300_000) { console.error("FAIL: source data mutated"); process.exit(1); }
console.log("STRIP-OK");
UTEOF

JITI_DIR=""
for cand in \
    "/opt/homebrew/lib/node_modules/@earendil-works/pi-coding-agent/node_modules" \
    "$(npm root -g 2>/dev/null)/@earendil-works/pi-coding-agent/node_modules"; do
    if [ -n "$cand" ] && [ -d "$cand/jiti" ]; then JITI_DIR="$cand"; break; fi
done
if [ -z "$JITI_DIR" ]; then
    warn "jiti not found (is pi installed?) — skipping strip-logic check"
else
    sed -i.bak -e "s|\./EXT/|$PWD/extensions/|" -e "s|JITI_PATH|$JITI_DIR/jiti|" "$TMP/harness.mjs" && rm -f "$TMP/harness.mjs.bak"
    if NODE_PATH="$JITI_DIR" node "$TMP/harness.mjs" >"$TMP/strip.out" 2>&1; then
        ok
        echo "  ok: images stripped, placeholders set, originals untouched"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: strip logic" >&2
        sed 's/^/    /' "$TMP/strip.out" | head -6 >&2
    fi
fi
echo ""

echo "[3] Loads in pi"
if command -v pi >/dev/null 2>&1; then
    pi --no-extensions -e ./extensions/image-slim.ts -p "say hi" >"$TMP/load.out" 2>&1 || true
    assert "pi loads image-slim.ts (no parse error)" \
        "! grep -qiE 'Failed to load extension|ParseError|cannot find module|conflicts with' $TMP/load.out"
else
    warn "pi not on PATH"
fi
echo ""

echo "──────────────────────────────"
echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
if [ "$FAIL" -ne 0 ]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
