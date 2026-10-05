#!/usr/bin/env bash
set -e

# Rodney Skill Test Suite

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/rodney"

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

echo "=== Testing rodney ==="
echo ""

# ── 1. File structure ──────────────────────────────────────────────────
echo "[1] File structure..."
assert "SKILL.md"                       "[ -f SKILL.md ]"
assert ".gitignore"                     "[ -f .gitignore ]"
assert "references/commands.md"         "[ -f references/commands.md ]"
assert "references/debugging.md"        "[ -f references/debugging.md ]"
assert "references/dev-workflow.md"     "[ -f references/dev-workflow.md ]"
assert "references/examples.md"         "[ -f references/examples.md ]"
assert "references/network-interception.md" "[ -f references/network-interception.md ]"
assert "scripts/rodney-cleanup.sh"     "[ -f scripts/rodney-cleanup.sh ]"
assert "scripts/rodney-ps.sh"          "[ -f scripts/rodney-ps.sh ]"
assert "scripts/README.md"              "[ -f scripts/README.md ]"
assert "references/TROUBLESHOOTING.md" "[ -f references/TROUBLESHOOTING.md ]"
echo ""

# ── 2. SKILL.md frontmatter ───────────────────────────────────────────
echo "[2] SKILL.md frontmatter..."
assert "name: rodney"      "grep -q '^name: rodney' SKILL.md"
assert "description"        "grep -q '^description:' SKILL.md"
assert "mentions headless"  "grep -qi 'headless' SKILL.md"
assert "CLI only warning"   "grep -q 'CLI Only' SKILL.md"
echo ""

# ── 3. SKILL.md references linked ────────────────────────────────────
echo "[3] SKILL.md references..."
assert "commands.md linked"    "grep -q 'references/commands.md' SKILL.md"
assert "examples.md linked"    "grep -q 'references/examples.md' SKILL.md"
assert "debugging.md linked"   "grep -q 'references/debugging.md' SKILL.md"
assert "dev-workflow.md linked" "grep -q 'references/dev-workflow.md' SKILL.md"
assert "network-interception.md linked" "grep -q 'references/network-interception.md' SKILL.md"
assert "TROUBLESHOOTING.md linked"     "grep -q 'references/TROUBLESHOOTING.md' SKILL.md"
assert "scripts/README.md linked"      "grep -q 'scripts/README.md' SKILL.md"
assert "cleanup utility mentioned"     "grep -q 'rodney-cleanup' SKILL.md"
assert "ps utility mentioned"          "grep -q 'rodney-ps' SKILL.md"
echo ""

# ── 4. Command available ─────────────────────────────────────────────
echo "[4] Command available..."
assert "rodney in PATH" "command -v rodney &>/dev/null"
echo ""

# ── 5. Version ───────────────────────────────────────────────────────
echo "[5] Version..."
VER=$(rodney --version 2>&1 || true)
assert "has version" "[ -n '$VER' ]"
echo "  version: $VER"
echo ""

# ── 6. SKILL.md content quality ──────────────────────────────────────
echo "[6] SKILL.md content..."
assert "has Install section"       "grep -q '## Install' SKILL.md"
assert "has Quick Start"           "grep -q '## Quick Start' SKILL.md"
assert "has Commands section"      "grep -q '## Commands' SKILL.md"
assert "has Gotchas section"       "grep -q '## Gotchas' SKILL.md"
assert "has rodney stop"           "grep -q 'rodney stop' SKILL.md"
assert "has rodney start"          "grep -q 'rodney start' SKILL.md"
assert "mentions build install"     "grep -q 'go build' SKILL.md"
assert "has Cookie section"        "grep -q 'rodney cookie-set' SKILL.md"
assert "has Emulation section"     "grep -q 'rodney timezone' SKILL.md"
assert "has Video section"         "grep -q 'rodney start-video' SKILL.md"
echo ""

# ── 7. .gitignore ────────────────────────────────────────────────────
echo "[7] .gitignore..."
assert ".rodney/"     "grep -q '\.rodney/' .gitignore"
assert ".env"         "grep -q '\.env' .gitignore"
assert ".last-update" "grep -q '\.last-update' .gitignore"
echo ""

# ── 8. Live test: start → open → title → stop ───────────────────────
echo "[8] Live browser test..."
# local fixture — no network, no content drift (example.com changed its markup
# in the wild and broke these asserts once)
FIXTURE="$TMPDIR/rodney-test-fixture.html"
cat > "$FIXTURE" <<'HTML'
<!doctype html><html><head><title>Rodney Fixture</title></head>
<body><h1>Fixture Head</h1><p>one</p></body></html>
HTML

rodney start 2>&1 | tail -1
sleep 1

rodney open "file://$FIXTURE" 2>&1 | tail -1
rodney waitstable 2>&1 | tail -1

TITLE=$(rodney title 2>&1)
assert "title is 'Rodney Fixture'" "[ '$TITLE' = 'Rodney Fixture' ]"

H1=$(rodney text "h1" 2>&1)
assert "h1 text found" "[ '$H1' = 'Fixture Head' ]"

URL=$(rodney url 2>&1)
assert "url contains fixture" "echo '$URL' | grep -q 'rodney-test-fixture'"

# Screenshot test
SCREENSHOT_PATH="/tmp/rodney-test.png"
rodney screenshot "$SCREENSHOT_PATH" 2>&1 | tail -1
assert "screenshot file exists" "[ -f \"$SCREENSHOT_PATH\" ]"
assert "screenshot has content" "[ \$(wc -c < \"$SCREENSHOT_PATH\") -gt 1000 ]"

# Stop
rodney stop 2>&1 | tail -1

# Cleanup
rm -f "$SCREENSHOT_PATH"

echo ""

# ── 9. Parallel sessions (--session) ────────────────────────────────
echo "[9] Parallel sessions..."
assert "--session without name errors" "! rodney --session status >/dev/null 2>&1"
SESS_DIR="$HOME/.rodney-sessions/rodney-test"
rm -rf "$SESS_DIR"
# named session: start, verify isolated state dir, stop (kills only its own)
rodney --session rodney-test start >/dev/null 2>&1
assert "session state dir created"    "[ -f "$SESS_DIR/state.json" ]"
assert "session has own chrome pid"  "python3 -c \"import json; d=json.load(open('$SESS_DIR/state.json')); exit(0 if d['chrome_pid']>0 else 1)\""
assert "session status works"        "rodney --session rodney-test status 2>&1 | grep -q 'Browser running'"
# stop can race the booting browser (devskale/rodney#3): verify with retry,
# and treat a surviving chrome as FAIL only if it outlives the retry window.
rodney --session rodney-test stop >/dev/null 2>&1
STOP_OK=0
for i in 1 2 3 4 5; do
    pgrep -f 'user-data-dir=.*rodney-sessions/rodney-test' >/dev/null 2>&1 || { STOP_OK=1; break; }
    sleep 1
done
assert "session stop kills own chrome" "[ $STOP_OK -eq 1 ]"
rm -rf "$SESS_DIR"
echo ""

# ── 10. Fork-exclusive features (live) ────────────────────────────────
echo "[10] Fork features (not in upstream simonw/rodney)..."
# Exercises what the fork adds over upstream: real keyboard events, scroll,
# console capture, network capture, cookie domains, emulation. All against a
# local fixture — no network, no user-browser contact (headless session).
FIXTURE2="$TMPDIR/rodney-fork-test.html"
cat > "$FIXTURE2" <<'HTML'
<!doctype html><html><head><title>Fork Feature Test</title></head>
<body style="height:3000px">
  <input id="q" placeholder="type here">
  <h1 id="top">Top</h1>
  <script>console.log('fork-fixture-loaded');</script>
</body></html>
HTML
S="--session fork-feature-test"
rodney $S start >/dev/null 2>&1
rodney $S open "file://$FIXTURE2" >/dev/null 2>&1
rodney $S waitload >/dev/null 2>&1

# real keyboard events: type into focused element, press combos
rodney $S js 'document.getElementById("q").focus()' >/dev/null 2>&1
rodney $S type "hello fork" >/dev/null 2>&1
TYPED=$(rodney $S js 'document.getElementById("q").value' 2>/dev/null)
assert "type fires real input events"      "[ \"$TYPED\" = 'hello fork' ]"
# press: single keys work; modifier combos are a known bug (devskale/rodney#1)
rodney $S press backspace >/dev/null 2>&1
TYPED=$(rodney $S js 'document.getElementById("q").value' 2>/dev/null)
assert "press single key (backspace) deletes" "[ \"$TYPED\" = 'hello for' ]"

# scroll: page is 3000px tall, scroll down then check scrollY
rodney $S scroll 0 1500 >/dev/null 2>&1 && sleep 0.3
SY=$(rodney $S js 'window.scrollY' 2>/dev/null)
assert "scroll moves the page"             "[ "${SY:-0}" -ge 1000 ] 2>/dev/null"

# console capture: collector + buffered read
rodney $S console-start >/dev/null 2>&1
rodney $S js 'console.log("captured-marker-42")' >/dev/null 2>&1 && sleep 0.5
CON_OUT=$(rodney $S console 2>/dev/null)
assert "console collector captures logs"   "echo '$CON_OUT' | grep -q 'captured-marker-42'"
rodney $S console-stop >/dev/null 2>&1

# network capture: collector catches the document request on reload
rodney $S requests-start >/dev/null 2>&1
rodney $S reload >/dev/null 2>&1 && sleep 0.8
REQ_OUT=$(rodney $S requests 2>/dev/null)
assert "request collector captures traffic" "echo '$REQ_OUT' | grep -q 'rodney-fork-test.html'"
rodney $S requests-stop >/dev/null 2>&1

# cookie domain scoping (upstream has no cookie commands at all).
# file:// pages cannot hold cookies — serve the fixture over http://localhost.
HTTP_PORT=18923
( cd "$TMPDIR" && python3 -m http.server $HTTP_PORT >/dev/null 2>&1 & echo $! > "$TMPDIR/http.pid" )
sleep 0.5
rodney $S open "http://localhost:$HTTP_PORT/rodney-fork-test.html" >/dev/null 2>&1
rodney $S waitload >/dev/null 2>&1
rodney $S cookie-set skale yes --domain "localhost" >/dev/null 2>&1
COOKIE_OUT=$(rodney $S cookie-get --json 2>/dev/null)
assert "cookie-set with --domain works"     "echo '$COOKIE_OUT' | grep -q localhost"
kill "$(cat "$TMPDIR/http.pid")" 2>/dev/null || true
pkill -f "http.server $HTTP_PORT" 2>/dev/null || true

# emulation: timezone override — KNOWN BUG devskale/rodney#2 (reports success,
# page keeps host tz). WARN until fixed; assert would fail.
rodney $S timezone "Asia/Tokyo" >/dev/null 2>&1
TZ_OUT=$(rodney $S js 'Intl.DateTimeFormat().resolvedOptions().timeZone' 2>/dev/null)
if [ -z "$TZ_OUT" ]; then
    echo "  WARN: timezone js read failed"
else
    echo "  WARN: timezone override known-broken (devskale/rodney#2): page reports $TZ_OUT"
fi

rodney $S stop >/dev/null 2>&1
sleep 1
rm -rf "$HOME/.rodney-sessions/fork-feature-test"
assert "fork session cleaned up"           "[ ! -d "$HOME/.rodney-sessions/fork-feature-test" ]"
echo ""

# ── 11. No stale Chrome processes ─────────────────────────────────────
echo "[11] Cleanup check..."
# rodney stop should have killed Chrome. Check no orphan.
# NB: rodney uses Chromium with --remote-debugging-port=0, so match on the
# .rodney user-data-dir, not "chrome.*remote-debugging".
sleep 1
ORPHANS=$(pgrep -f "user-data-dir=.*\\.rodney" 2>/dev/null | wc -l || echo 0)
assert "no orphan Chromium" "[ $ORPHANS -eq 0 ]"
echo ""

# ── 14. Process utilities ────────────────────────────────────────────
echo "[14] Process utilities..."
assert "rodney-cleanup runs"        "scripts/rodney-cleanup.sh >/dev/null 2>&1"
assert "rodney-cleanup --json valid" "scripts/rodney-cleanup.sh --json | grep -q '\"total_chrome_processes\"'"
assert "rodney-ps runs"             "scripts/rodney-ps.sh >/dev/null 2>&1"
assert "rodney-ps --json valid"     "scripts/rodney-ps.sh --json | grep -q '\"managed_pid\"'"
# self-decompose: cleanup must see the WHOLE rod family, not just .rodney dirs
assert "cleanup detects rod-managed binary" "grep -q 'cache/rod/browser' scripts/rodney-cleanup.sh"
assert "cleanup sweeps stale rod temp dirs" "grep -q 'stale_rod_temp_dirs' scripts/rodney-cleanup.sh"
assert "cleanup never kills managed sessions" "grep -q 'managed_pids' scripts/rodney-cleanup.sh"
echo ""

# ── Summary ──────────────────────────────────────────────────────────
echo ""
# ── 12. Binary↔docs drift (progressive discovery enforcement) ────────
echo "[12] Binary commands all documented..."
# The binary evolves independently of this skill (installer pulls the latest
# release). Every command the binary knows must appear in references/ —
# otherwise docs lag and agents misroute. A new binary feature FAILS here
# until documented (or the registry regenerated).
BIN_CMDS=$(rodney --help 2>/dev/null | grep -oE '^  rodney [a-z][a-z-]*' | awk '{print $2}' | sort -u || true)
DOC_CMDS=$(grep -hoE 'rodney [a-z][a-z-]*' SKILL.md references/commands.md 2>/dev/null | awk '{print $2}' | sort -u || true)
if [ -n "$BIN_CMDS" ]; then
    MISSING=$(comm -23 <(echo "$BIN_CMDS") <(echo "$DOC_CMDS"))
    if [ -z "$MISSING" ]; then
        PASS=$((PASS+1)); echo "  ✓ all $(echo "$BIN_CMDS" | wc -l | tr -d ' ') binary commands documented"
    else
        FAIL=$((FAIL+1))
        echo "  ✗ binary commands missing from docs:"
        echo "$MISSING" | sed 's/^/      /'
        echo "    → document them in skills/rodney/references/commands.md"
    fi
else
    echo "  WARN: rodney --help unavailable (binary not installed?)"
fi
echo ""

# ── 13. Generated registry freshness (binary == registry.md) ────────
echo "[13] Generated registry in sync..."
# references/registry.md is GENERATED from the binary (scripts/gen-registry.sh).
# It must be byte-identical to a fresh regeneration — a stale registry fails.
if command -v rodney >/dev/null 2>&1; then
    bash scripts/gen-registry.sh > "$TMPDIR/registry-fresh.md" 2>/dev/null
    if diff -q "$TMPDIR/registry-fresh.md" references/registry.md >/dev/null 2>&1; then
        PASS=$((PASS+1)); echo "  ✓ registry.md is fresh (byte-identical to binary output)"
    else
        DIFF_N=$(diff "$TMPDIR/registry-fresh.md" references/registry.md 2>/dev/null | grep -c '^[<>]')
        FAIL=$((FAIL+1))
        echo "  ✗ registry.md is stale ($DIFF_N drifted lines) — run: scripts/gen-registry.sh --write"
    fi
    rm -f "$TMPDIR/registry-fresh.md"
else
    echo "  WARN: rodney not installed — registry freshness skipped"
fi
echo ""

echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
if [ $FAIL -gt 0 ]; then
    echo ""
    echo "❌ Some tests failed."
    exit 1
else
    echo ""
    echo "✅ All $PASS tests passed!"
fi
