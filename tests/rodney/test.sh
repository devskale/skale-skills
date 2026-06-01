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
assert "mentions uv tool install"  "grep -q 'uv tool install rodney' SKILL.md"
echo ""

# ── 7. .gitignore ────────────────────────────────────────────────────
echo "[7] .gitignore..."
assert ".rodney/"     "grep -q '\.rodney/' .gitignore"
assert ".env"         "grep -q '\.env' .gitignore"
assert ".last-update" "grep -q '\.last-update' .gitignore"
echo ""

# ── 8. Live test: start → open → title → stop ───────────────────────
echo "[8] Live browser test..."
rodney start 2>&1 | tail -1
sleep 1

rodney open https://example.com 2>&1 | tail -1
rodney waitstable 2>&1 | tail -1

TITLE=$(rodney title 2>&1)
assert "title is 'Example Domain'" "[ '$TITLE' = 'Example Domain' ]"

H1=$(rodney text "h1" 2>&1)
assert "h1 text found" "[ '$H1' = 'Example Domain' ]"

URL=$(rodney url 2>&1)
assert "url contains example.com" "echo '$URL' | grep -q 'example.com'"

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

# ── 9. No stale Chrome processes ─────────────────────────────────────
echo "[9] Cleanup check..."
# rodney stop should have killed Chrome. Check no orphan.
sleep 1
ORPHANS=$(pgrep -f "chrome.*remote-debugging" 2>/dev/null | wc -l || echo 0)
assert "no orphan Chrome" "[ $ORPHANS -eq 0 ]"
echo ""

# ── Summary ──────────────────────────────────────────────────────────
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
