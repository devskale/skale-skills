#!/usr/bin/env bash
set -e

# Web Search Skill Test Script
# Tests structural and functional properties of the web-search skill (v2)

# Resolve skill directory and cd into it
cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/web-search"

echo "=== Testing web-search skill (v2) ==="
echo "Skill directory: $(pwd)"
echo ""

PASS=0
FAIL=0

assert() {
    if eval "$2"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $1"
    fi
}

# ── Test 1: Script exists ────────────────────────────────────────────────
echo "[1] Checking scripts/search.py exists..."
assert "search.py exists" "[ -f 'scripts/search.py' ]"
echo ""

# ── Test 2: Help message matches v2 ───────────────────────────────────────
echo "[2] Checking help message matches v2..."
HELP_OUTPUT=$(uv run scripts/search.py --help 2>&1)
assert "help mentions 'public instances'" "echo '$HELP_OUTPUT' | grep -q 'public instances'"
assert "help mentions --categories"        "echo '$HELP_OUTPUT' | grep -q '\-\-categories'"
assert "help mentions --time-range"        "echo '$HELP_OUTPUT' | grep -q '\-\-time-range'"
assert "help mentions --engines"           "echo '$HELP_OUTPUT' | grep -q '\-\-engines'"
assert "help mentions --api flag"          "echo '$HELP_OUTPUT' | grep -q '\-\-api'"
assert "help mentions --searxng flag"      "echo '$HELP_OUTPUT' | grep -q '\-\-searxng'"
echo ""

# ── Test 3: Query argument is required ──────────────────────────────────
echo "[3] Checking query argument is required..."
if ! uv run scripts/search.py 2>&1 | grep -qi "required.*query"; then
    FAIL=$((FAIL + 1))
    echo "FAIL: query argument not enforced"
else
    PASS=$((PASS + 1))
fi
echo ""

# ── Test 4: Type hints present ──────────────────────────────────────────
echo "[4] Checking type hints..."
assert "typing imports present" "grep -q 'from typing import' scripts/search.py"
assert "Optional used"          "grep -q 'Optional' scripts/search.py"
assert "Dict used"              "grep -q 'Dict' scripts/search.py"
assert "List used"              "grep -q 'List' scripts/search.py"
echo ""

# ── Test 5: Docstrings present ───────────────────────────────────────────
echo "[5] Checking docstrings..."
DOCSTRING_COUNT=$(grep -c '"""' scripts/search.py)
assert "docstrings present (>= 6, got $DOCSTRING_COUNT)" "[ $DOCSTRING_COUNT -ge 6 ]"
echo ""

# ── Test 6: SKILL.md frontmatter ────────────────────────────────────────
echo "[6] Checking SKILL.md frontmatter..."
assert "name: web-search"    "grep -q '^name: web-search' SKILL.md"
assert "description present" "grep -q '^description:' SKILL.md"
assert "version 2.0"         "grep -q 'version.*2.0' SKILL.md"
echo ""

# ── Test 7: Credgoo support ───────────────────────────────────────────────
echo "[7] Checking credgoo support..."
assert "credgoo in script"       "grep -q 'credgoo' scripts/search.py"
assert "credgoo in .env.example" "grep -q 'credgoo' .env.example"
assert "credgoo in pyproject"    "grep -q 'credgoo' pyproject.toml"
echo ""

# ── Test 8: pyproject.toml version matches SKILL.md ──────────────────────
echo "[8] Checking version alignment..."
TOML_VERSION=$(grep '^version' pyproject.toml | head -1 | grep -o '[0-9][0-9.]*')
assert "pyproject.toml version ($TOML_VERSION) is 2.x" "echo '$TOML_VERSION' | grep -q '^2\.'"
echo ""

# ── Test 9: Launcher macOS compatibility ───────────────────────────────
echo "[9] Checking launcher macOS compatibility..."
assert "no readlink -f (breaks macOS)" "grep -qv 'readlink -f' search"
assert "uses BASH_SOURCE"               "grep -q 'BASH_SOURCE' search"
echo ""

# ── Test 10: Backend selection logic ────────────────────────────────────
echo "[10] Checking backend selection logic..."
assert "select_backend function"  "grep -q 'def select_backend' scripts/search.py"
assert "search_duck function"    "grep -q 'def search_duck' scripts/search.py"
assert "search_searxng function" "grep -q 'def search_searxng' scripts/search.py"
assert "get_bearer_token"       "grep -q 'def get_bearer_token' scripts/search.py"
assert "get_searxng_credentials""grep -q 'def get_searxng_credentials' scripts/search.py"
echo ""

# ── Test 11: SearXNG credentials return None when unconfigured ──────────
echo "[11] Checking get_searxng_credentials returns None when unconfigured..."
assert "returns None at end"        "grep -q 'return None' scripts/search.py"
assert "parse helper returns None"  "grep -q '_parse_searxng_cred' scripts/search.py"
assert "empty URL returns None"     "grep -q 'if not url' scripts/search.py"
echo ""

# ── Test 12: Error diagnostics ──────────────────────────────────────────
echo "[12] Checking SearXNG error diagnostics..."
assert "last_error tracked"  "grep -q 'last_error' scripts/search.py"
echo ""

# ── Test 13: Duck API timeout ───────────────────────────────────────────
echo "[13] Checking Duck API timeout..."
assert "timeout tuple (5, 15)" "grep -q 'timeout=(5, 15)' scripts/search.py"
echo ""

# ── Test 14: Error sanitization ────────────────────────────────────────
echo "[14] Checking error message sanitization..."
assert "strips Authorization from errors" "grep -q 'split.*Authorization' scripts/search.py"
echo ""

# ── Test 15: .gitignore ─────────────────────────────────────────────────
echo "[15] Checking .gitignore..."
assert ".venv/ ignored"      "grep -q '\.venv/' .gitignore"
assert "*.egg-info/ ignored" "grep -q '\*\.egg-info/' .gitignore"
assert "uv.lock ignored"      "grep -q 'uv.lock' .gitignore"
assert ".env ignored"        "grep -q '\.env' .gitignore"
echo ""

# ── Summary ──────────────────────────────────────────────────────────────
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
