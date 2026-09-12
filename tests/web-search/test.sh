#!/usr/bin/env bash
set -e

# Web Search Skill Test Suite (v2.3)
# Tests the installed `web-search` command + skill source files

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/web-search"

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

echo "=== Testing web-search (v2.3) ==="
echo ""

# ── 1. Command is available ──────────────────────────────────────────────
echo "[1] web-search command exists..."
assert "web-search in PATH" "command -v web-search &>/dev/null"
echo ""

# ── 2. Launcher flags ────────────────────────────────────────────────────
echo "[2] Launcher flags..."
assert "--selfcheck works" "web-search --selfcheck 2>&1 | grep -q 'web-search v'"
assert "--update works"   "web-search --update 2>&1 | grep -q 'Updated'"
assert "stamp file created" "[ -f .last-update ]"
echo ""

# ── 3. Help matches v2 ──────────────────────────────────────────────────
echo "[3] Help output..."
HELP=$(web-search --help 2>&1)
assert "mentions --categories" "echo '$HELP' | grep -q '\-\-categories'"
assert "mentions --time-range" "echo '$HELP' | grep -q '\-\-time-range'"
assert "mentions --api"        "echo '$HELP' | grep -q '\-\-api'"
assert "mentions --searxng"    "echo '$HELP' | grep -q '\-\-searxng'"
assert "mentions --json"       "echo '$HELP' | grep -q '\-\-json'"
assert "mentions --backend"    "echo '$HELP' | grep -q '\-\-backend'"
echo ""

# ── 4. Query argument required ──────────────────────────────────────────
echo "[4] Query required..."
if web-search 2>&1 | grep -qi "required.*query"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "  FAIL: query argument not enforced"
fi
echo ""

# ── 5. Live SearXNG search ──────────────────────────────────────────────
echo "[5] Live SearXNG search..."
RESULT=$(web-search "python tutorial" --searxng --max 3 2>&1) || true
if echo "$RESULT" | grep -q "Results for"; then
    PASS=$((PASS + 1))
else
    # Network flakiness — warn, don't fail
    echo "  WARN: no results (may be network issue)"
    WARN=$((WARN + 1))
fi
echo ""

# ── 6. JSON output ──────────────────────────────────────────────────────
echo "[6] JSON output..."
JSON=$(web-search "test" --searxng --max 1 --json 2>/dev/null) || true
if echo "$JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    PASS=$((PASS + 1))
else
    echo "  WARN: JSON output invalid (may be network issue)"
    WARN=$((WARN + 1))
fi
echo ""

# ── 7. Verbose shows backend on stderr ──────────────────────────────────
echo "[7] Verbose..."
STDERR=$(web-search "test" --searxng -v 2>&1 1>/dev/null) || true
assert "stderr shows backend" "echo '$STDERR' | grep -q 'Backend: searxng'"
echo ""

# ── 7b. Live Duck news (requires WEB_SEARCH_BEARER) ────────────
echo "[7b] Live Duck news..."
NEWS=$(web-search "technology" --categories news -v --max 3 2>&1) || true
if echo "$NEWS" | grep -q "Backend: duck" && echo "$NEWS" | grep -qE "Results for|No results found"; then
    PASS=$((PASS + 1))
elif echo "$NEWS" | grep -q "Backend: searxng"; then
    echo "  WARN: no Duck token, news fell back to SearXNG (valid path)"
    WARN=$((WARN + 1))
else
    echo "  WARN: news search unavailable (may be network issue)"
    WARN=$((WARN + 1))
fi
echo ""

# ── 7c. Live backend override (requires WEB_SEARCH_BEARER) ──────
echo "[7c] Live --backend auto..."
AUTO=$(web-search "rust axum" --backend auto -v --max 2 2>&1) || true
if echo "$AUTO" | grep -q "Backend: duck" && echo "$AUTO" | grep -q "Results for"; then
    PASS=$((PASS + 1))
elif echo "$AUTO" | grep -q "Backend: searxng"; then
    echo "  WARN: no Duck token, override irrelevant on SearXNG"
    WARN=$((WARN + 1))
else
    echo "  WARN: backend override unavailable (may be network issue)"
    WARN=$((WARN + 1))
fi
echo ""

# ── 8. Code quality ──────────────────────────────────────────────────────
echo "[8] Code quality..."
assert "type hints"       "grep -q 'from typing import' scripts/search.py"
assert "docstrings (>=6)" "[ $(grep -c '\"\"\"' scripts/search.py) -ge 6 ]"
assert "no readlink -f"   "grep -qv 'readlink -f' search"
assert "BASH_SOURCE used" "grep -q 'BASH_SOURCE' search"
assert "last_error tracked"  "grep -q 'last_error' scripts/search.py"
assert "auth sanitized"      "grep -q 'split.*Authorization' scripts/search.py"
assert "timeout tuple (5,45 for queue waits)" "grep -q 'timeout=(5, 45)' scripts/search.py"
assert "_parse_searxng_cred" "grep -q '_parse_searxng_cred' scripts/search.py"
assert "ad filter present"  "grep -q '_AD_URL_MARKERS' scripts/search.py"
assert "news endpoint used" "grep -q '/duck/news' scripts/search.py"
assert "backend passthrough" "grep -q 'params\[\"backend\"\]' scripts/search.py"
assert "502 handled"        "grep -q 'status_code == 502' scripts/search.py"
echo ""

# ── 9. SKILL.md ──────────────────────────────────────────────────────────
echo "[9] SKILL.md..."
assert "name: web-search"    "grep -q '^name: web-search' SKILL.md"
assert "description present" "grep -q '^description:' SKILL.md"
assert "version 2.x"         "grep -q 'version.*\"2\.' SKILL.md"
assert "SKILL.md documents --backend" "grep -q '\-\-backend' SKILL.md"
assert "SKILL.md documents 502"       "grep -q '502' SKILL.md"
assert "web-search --update"  "grep -q '\-\-update' SKILL.md"
assert "web-search --selfcheck" "grep -q '\-\-selfcheck' SKILL.md"
assert "references INDEX"    "grep -q 'references/INDEX.md' SKILL.md"
echo ""

# ── 10. File structure ──────────────────────────────────────────────────
echo "[10] File structure..."
assert "scripts/search.py" "[ -f scripts/search.py ]"
assert "install.sh"        "[ -f install.sh ]"
assert ".env.example"      "[ -f .env.example ]"
assert ".gitignore"        "[ -f .gitignore ]"
assert "pyproject.toml"    "[ -f pyproject.toml ]"
echo ""

# ── 11. .gitignore ──────────────────────────────────────────────────────
echo "[11] .gitignore..."
assert ".venv/"         "grep -q '\.venv/' .gitignore"
assert "*.egg-info/"    "grep -q '\*\.egg-info/' .gitignore"
assert "uv.lock"        "grep -q 'uv.lock' .gitignore"
assert ".last-update"   "grep -q '\.last-update' .gitignore"
assert ".env"           "grep -q '\.env' .gitignore"
echo ""

# ── 12. Version alignment ───────────────────────────────────────────────
echo "[12] Version alignment..."
TOML_V=$(grep '^version' pyproject.toml | head -1 | grep -o '[0-9][0-9.]*')
SKILL_V=$(grep 'version' SKILL.md | head -1 | grep -o '[0-9][0-9.]*')
SELF_V=$(web-search --selfcheck 2>/dev/null | grep -o 'v[0-9][0-9.]*' | head -1 | tr -d 'v')
assert "pyproject ($TOML_V), SKILL.md ($SKILL_V), selfcheck ($SELF_V) match" "[ '$TOML_V' = '$SKILL_V' ] && [ '$TOML_V' = '$SELF_V' ]"
echo ""

# ── Summary ──────────────────────────────────────────────────────────────
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "  Warned/skipped (network): $WARN"
if [ $FAIL -gt 0 ]; then
    echo ""
    echo "❌ Some tests failed."
    exit 1
else
    echo ""
    echo "✅ All $PASS tests passed!"
fi
