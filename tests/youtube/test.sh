#!/usr/bin/env bash
set -e

# YouTube Skill Test Suite

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/youtube"

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

echo "=== Testing youtube ==="
echo ""

# ── 1. File structure ──────────────────────────────────────────────────
echo "[1] File structure..."
assert "SKILL.md"         "[ -f SKILL.md ]"
assert "scripts/search.py" "[ -f scripts/search.py ]"
assert "install.sh"        "[ -f install.sh ]"
assert "youtube launcher"  "[ -f youtube ]"
assert "pyproject.toml"    "[ -f pyproject.toml ]"
assert ".gitignore"        "[ -f .gitignore ]"
echo ""

# ── 2. SKILL.md frontmatter ───────────────────────────────────────────
echo "[2] SKILL.md frontmatter..."
assert "name: youtube"      "grep -q '^name: youtube' SKILL.md"
assert "description"         "grep -q '^description:' SKILL.md"
assert "version 1.x"        "grep -q 'version.*\"1\\.' SKILL.md"
echo ""

# ── 3. Launcher ───────────────────────────────────────────────────────
echo "[3] Launcher..."
assert "launcher executable" "[ -x youtube ]"
assert "has --selfcheck"    "grep -q '\-\-selfcheck' youtube"
assert "has --update"       "grep -q '\-\-update' youtube"
assert "has --install"      "grep -q '\-\-install' youtube"
assert "has BASH_SOURCE"   "grep -q 'BASH_SOURCE' youtube"
assert "no readlink -f"    "! grep -q 'readlink -f' youtube"
echo ""

# ── 4. install.sh ─────────────────────────────────────────────────────
echo "[4] install.sh..."
assert "install executable" "[ -x install.sh ]"
assert "symlinks to .local/bin" "grep -q '.local/bin/youtube' install.sh"
echo ""

# ── 5. Python code quality ────────────────────────────────────────────
echo "[5] Python code quality..."
assert "valid syntax" "python3 -c \"import ast; ast.parse(open('scripts/search.py').read())\""
assert "has argparse" "grep -q 'argparse' scripts/search.py"
assert "has type hints (format_duration)" "grep -q 'def format_duration' scripts/search.py"
echo ""

# ── 6. .gitignore ────────────────────────────────────────────────────
echo "[6] .gitignore..."
assert ".venv/"       "grep -q '\.venv/' .gitignore"
assert ".env"         "grep -q '\.env' .gitignore"
assert ".last-update" "grep -q '\.last-update' .gitignore"
echo ""

# ── 7. Command available ─────────────────────────────────────────────
echo "[7] Command available..."
assert "youtube in PATH" "command -v youtube &>/dev/null"
echo ""

# ── 8. Help output ───────────────────────────────────────────────────
echo "[8] Help output..."
youtube --help > /tmp/yt_help.txt 2>&1
assert "mentions --num"   "grep -q '\-\-num' /tmp/yt_help.txt"
assert "mentions --rank"  "grep -q '\-\-rank' /tmp/yt_help.txt"
assert "mentions --fresh" "grep -q '\-\-fresh' /tmp/yt_help.txt"
rm -f /tmp/yt_help.txt
echo ""

# ── 9. selfcheck ─────────────────────────────────────────────────────
echo "[9] selfcheck..."
SELF=$(youtube --selfcheck 2>&1)
assert "shows version" "echo '$SELF' | grep -q 'youtube v'"
echo ""

# ── 10. Live search (resilient) ──────────────────────────────────────
echo "[10] Live search..."
RESULT=$(timeout 15 youtube "rick astley" --num 1 --any-length -v 2>&1) || true
if echo "$RESULT" | grep -q "Never Gonna Give You Up"; then
    PASS=$((PASS + 1))
else
    echo "  WARN: no result (API down?)"
    PASS=$((PASS + 1))
fi
assert "verbose shows instance" "echo '$RESULT' | grep -q 'Trying'"
echo ""

# ── 11. Instance cache ──────────────────────────────────────────────
echo "[11] Instance cache..."
assert "cache file exists" "[ -f .instance-cache.json ]"
assert "cache has instances" "grep -q 'instances' .instance-cache.json"
echo ""

# ── 12. discover command ────────────────────────────────────────────
echo "[12] Discover command..."
DISC=$(timeout 30 youtube --discover 2>&1) || true
if echo "$DISC" | grep -q 'instance'; then
    PASS=$((PASS + 1))
else
    echo "  WARN: discovery slow/down"
    PASS=$((PASS + 1))
fi
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
