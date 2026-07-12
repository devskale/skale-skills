#!/usr/bin/env bash
set -e

# Surf Skill Test Suite
# Live tests require macOS + Google Chrome with "Allow JavaScript from Apple Events" ON.

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/surf"

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

echo "=== Testing surf ==="
echo ""

# ── 1. File structure ─────────────────────────────────────────────────
echo "[1] File structure..."
assert "SKILL.md"              "[ -f SKILL.md ]"
assert "surf launcher"         "[ -f surf ]"
assert "scripts/surf.sh"       "[ -f scripts/surf.sh ]"
assert "install.sh"            "[ -f install.sh ]"
assert "install.bat"           "[ -f install.bat ]"
assert ".gitignore"            "[ -f .gitignore ]"
assert "references/commands.md" "[ -f references/commands.md ]"
echo ""

# ── 2. SKILL.md frontmatter ───────────────────────────────────────────
echo "[2] SKILL.md frontmatter..."
assert "name: surf"        "grep -q '^name: surf' SKILL.md"
assert "description"       "grep -q '^description:' SKILL.md"
assert "mentions AppleScript" "grep -qi 'applescript' SKILL.md"
assert "CLI only warning"  "grep -q 'CLI Only' SKILL.md"
assert "macOS-only noted"  "grep -qi 'macOS-only' SKILL.md"
echo ""

# ── 3. SKILL.md references linked ─────────────────────────────────────
echo "[3] SKILL.md references..."
assert "commands.md linked" "grep -q 'references/commands.md' SKILL.md"
echo ""

# ── 4. Command available ──────────────────────────────────────────────
echo "[4] Command available..."
assert "surf in PATH"  "command -v surf &>/dev/null"
echo ""

# ── 5. Version ────────────────────────────────────────────────────────
echo "[5] Version..."
VER=$(surf --version 2>&1 || true)
assert "has version" "[ -n '$VER' ]"
echo "  version: $VER"
echo ""

# ── 6. SKILL.md content quality ───────────────────────────────────────
echo "[6] SKILL.md content..."
assert "has Install section"  "grep -q '## Install' SKILL.md"
assert "has Commands section" "grep -q '## Commands' SKILL.md"
assert "has Gotchas section"  "grep -q '## Gotchas' SKILL.md"
assert "mentions setup"       "grep -q 'surf setup' SKILL.md"
assert "lists click/fill/text" "grep -q 'surf click' SKILL.md"
echo ""

# ── 7. .gitignore ─────────────────────────────────────────────────────
echo "[7] .gitignore..."
assert ".last-update" "grep -q '\.last-update' .gitignore"
assert ".env"         "grep -q '\.env' .gitignore"
echo ""

# ── 8. Launcher flags ─────────────────────────────────────────────────
echo "[8] Launcher flags..."
assert "--selfcheck works" "surf --selfcheck >/dev/null 2>&1"
assert "help works"        "surf help >/dev/null 2>&1"
echo ""

# ── 9. Live test (macOS + Chrome + JS toggle) ─────────────────────────
echo "[9] Live browser test..."
if [ "$(uname)" != "Darwin" ]; then
    echo "  SKIP: not macOS"
elif ! command -v osascript &>/dev/null; then
    echo "  SKIP: no osascript"
else
    # open a deterministic page in a fresh tab
    surf new "https://example.com" >/dev/null 2>&1 && sleep 1.5 || true
    assert "here returns URL"        "surf here 2>/dev/null | grep -q 'example.com'"
    assert "text h1 reads"           "[ \"\$(surf text 'h1' 2>/dev/null)\" = 'Example Domain' ]"
    assert "count p is 2"            "[ \"\$(surf count 'p' 2>/dev/null)\" = '2' ]"
    assert "eval returns JSON-ish"   "surf eval '1+1' 2>/dev/null | grep -q '2'"
    assert "title works"             "surf title 2>/dev/null | grep -qi 'example'"
fi
echo ""

echo "==============================="
echo "  PASS: $PASS   FAIL: $FAIL"
echo "==============================="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
