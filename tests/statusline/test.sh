#!/usr/bin/env bash
# tests/statusline/test.sh — statusline is the only extension without a suite.
# These are structural checks (the extension's behaviour is TUI rendering, hard to
# assert headless); they catch the two failure modes that actually happened:
# the doc going orphaned, and the file not loading in pi at all.
set -uo pipefail
cd "$(dirname "$0")/../.."

PASS=0; FAIL=0; WARN=0
ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN + 1)); echo "  WARN (skipped honestly): $1" >&2; }
assert() { # assert <desc> <command>
    if eval "$2" >/dev/null 2>&1; then ok; else bad "$1"; fi
}

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "statusline tests"
echo "----------------"

echo "[1] File structure"
assert "extensions/statusline.ts exists"        "[ -f extensions/statusline.ts ]"
assert "extensions/statusline.md doc exists"    "[ -f extensions/statusline.md ]"
assert "pi.extensions glob ships extensions/*.ts (covers statusline)" \
    "grep -q '\\./extensions/\\*\\.ts' package.json"
assert "AGENTS.md references statusline"        "grep -q 'statusline' AGENTS.md"
assert "README.md references statusline"        "grep -q 'statusline' README.md"

echo ""
echo "[2] Doc consistency"
# The doc's headline features must still exist in the code — catches doc/code drift
# cheaply, without a TUI harness.
for feature in "machineName" "zai|quota" "compact|narrow"; do
    assert "doc mentions a feature the code has ($feature)" \
        "grep -qiE '$feature' extensions/statusline.md && grep -qiE \"$feature\" extensions/statusline.ts"
done

echo ""
echo "[3] Compiles standalone"
if command -v pi >/dev/null 2>&1; then
    # --no-extensions isolates the repo copy from the installed package copy (name conflicts).
    pi --no-extensions -e ./extensions/statusline.ts -p "say hi" >"$TMP/load.out" 2>&1 || true
    assert "pi loads statusline.ts (no parse error)" \
        "! grep -qiE 'Failed to load extension|ParseError|cannot find module|conflicts with' $TMP/load.out"
else
    warn "pi not on PATH"
fi

echo ""
echo "[4] Auto-compaction flag is read from settings, not hardcoded"
# Regression (2026-10-11): "(auto)" was appended unconditionally — the doc claimed
# it could not know better, but pi's own source of truth (settings.compaction.enabled,
# default true) is on disk and readable. These checks pin the behaviour.
assert "reads compaction.enabled from settings" \
    "grep -q 'readAutoCompactionEnabled' extensions/statusline.ts"
assert "reads the user settings file" \
    "grep -q 'settings.json' extensions/statusline.ts"
assert "defaults to enabled when the key is absent (pi's own default)" \
    "grep -q 'let enabled = true' extensions/statusline.ts"
assert "caches the read (60s TTL) so the footer stays cheap" \
    "grep -q 'AUTO_COMPACTION_TTL_MS' extensions/statusline.ts"
assert "doc no longer claims the flag is unknowable" \
    "! grep -qi 'does not expose that flag' extensions/statusline.ts"
assert "doc explains the settings-file source" \
    "grep -qi 'settings files' extensions/statusline.md"

echo ""
echo "[5] imagegen carries a VERSION (parity with xmodel/image-slim/heartbeat)"
assert "imagegen.ts defines VERSION" "grep -q 'const VERSION = ' extensions/imagegen.ts"
assert "imagegen surfaces the version in help" "grep -q 'imagegen v\${VERSION}' extensions/imagegen.ts"
assert "imagegen surfaces the version in the success notify" \
    "grep -q 'imagegen v\${VERSION}:' extensions/imagegen.ts"
assert "every extension defines a VERSION" \
    "for f in extensions/imagegen.ts extensions/image-slim.ts extensions/xmodel.ts; do grep -q 'VERSION = ' \$f || exit 1; done"

echo ""
echo "──────────────────────────────"
echo "PASS: $PASS  FAIL: $FAIL  WARN: $WARN"
if [ "$FAIL" -ne 0 ]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
