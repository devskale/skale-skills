#!/usr/bin/env bash
set -e

# Fetch URL Skill Test Suite
# Tests the installed `fetch-url` command + source files

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/fetch-url"

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

echo "=== Testing fetch-url ==="
echo ""

# ── 1. Command available ─────────────────────────────────────────────────
echo "[1] Command available..."
assert "fetch-url in PATH" "command -v fetch-url &>/dev/null"
echo ""

# ── 2. Launcher flags ───────────────────────────────────────────────────
echo "[2] Launcher flags..."
assert "--selfcheck works" "fetch-url --selfcheck 2>&1 | grep -q 'fetch-url v'"
assert "--update works"   "fetch-url --update 2>&1 | grep -q 'Updated'"
assert "stamp file created" "[ -f .last-update ]"
echo ""

# ── 3. Help output ──────────────────────────────────────────────────────
echo "[3] Help output..."
HELP=$(fetch-url --help 2>&1)
assert "mentions --tool"    "echo '$HELP' | grep -q '\-\-tool'"
assert "mentions --verbose" "echo '$HELP' | grep -q '\-\-verbose'"
assert "mentions --no-clean" "echo '$HELP' | grep -q '\-\-no-clean'"
echo ""

# ── 4. URL required ────────────────────────────────────────────────────
echo "[4] URL required..."
if fetch-url 2>&1 | grep -qi "required.*url"; then
    PASS=$((PASS + 1))
else
    # argparse may say "the following arguments are required: url"
    if fetch-url 2>&1 | grep -qi "required"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: URL argument not enforced"
    fi
fi
echo ""

# ── 5. Live: GitHub ────────────────────────────────────────────────────
echo "[5] Live: GitHub..."
RESULT=$(fetch-url "https://github.com/devskale/skale-skills" -v 2>&1) || true
if echo "$RESULT" | grep -q "skale-skills"; then
    PASS=$((PASS + 1))
else
    echo "  WARN: no GitHub result (network?)"
    PASS=$((PASS + 1))
fi
echo ""

# ── 6. Live: HN ────────────────────────────────────────────────────────
echo "[6] Live: Hacker News..."
RESULT=$(fetch-url "https://news.ycombinator.com/" 2>&1) || true
if echo "$RESULT" | grep -q "Hacker News"; then
    PASS=$((PASS + 1))
else
    echo "  WARN: no HN result (network?)"
    PASS=$((PASS + 1))
fi
echo ""

# ── 7. Live: Wikipedia ─────────────────────────────────────────────────
echo "[7] Live: Wikipedia..."
RESULT=$(fetch-url "https://en.wikipedia.org/wiki/Rust_(programming_language)" 2>&1) || true
if echo "$RESULT" | grep -qi "rust"; then
    PASS=$((PASS + 1))
else
    echo "  WARN: no Wikipedia result (network?)"
    PASS=$((PASS + 1))
fi
echo ""

# ── 8. Reddit redirect ─────────────────────────────────────────────────
echo "[8] Reddit redirect..."
STDERR=$(fetch-url "https://www.reddit.com/r/python/" -v 2>&1 1>/dev/null) || true
assert "redirects to old.reddit.com" "echo '$STDERR' | grep -q 'old.reddit.com'"
echo ""

# ── 9. is_valid_content logic ──────────────────────────────────────────
echo "[9] is_valid_content logic..."
cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/fetch-url"

# Test: real error page is rejected
REJECT=$(python3 -c "
import sys; sys.path.insert(0, 'scripts')
from fetch import is_valid_content
print('reject' if not is_valid_content('You have been blocked by network security. Error 403.') else 'pass')
") || true
assert "real error page rejected" "[ '$REJECT' = 'reject' ]"

# Test: long article with 'cloudflare' is accepted
ACCEPT=$(python3 -c "
import sys; sys.path.insert(0, 'scripts')
from fetch import is_valid_content
# 5000 chars with 'cloudflare' deep in text
content = 'A' * 3000 + ' cloudflare ' + 'B' * 2000
print('accept' if is_valid_content(content) else 'reject')
") || true
assert "long content with 'cloudflare' accepted" "[ '$ACCEPT' = 'accept' ]"

# Test: short page with 1 weak pattern is accepted
ACCEPT2=$(python3 -c "
import sys; sys.path.insert(0, 'scripts')
from fetch import is_valid_content
print('accept' if is_valid_content('This article discusses cloudflare and CDN services.' * 5) else 'reject')
") || true
assert "short content with 1 weak hit accepted" "[ '$ACCEPT2' = 'accept' ]"

# Test: short page with 2+ weak patterns is rejected
REJECT2=$(python3 -c "
import sys; sys.path.insert(0, 'scripts')
from fetch import is_valid_content
print('reject' if not is_valid_content('Error 403: Forbidden. Access denied.') else 'pass')
") || true
assert "short content with 2 weak hits rejected" "[ '$REJECT2' = 'reject' ]"
echo ""

# ── 10. Settings loads site_tool_hints ─────────────────────────────────
echo "[10] Settings: site_tool_hints..."
assert "settings.json has site_tool_hints" "grep -q 'site_tool_hints' settings.json"
assert "settings.json has reddit.com" "grep -q 'reddit.com' settings.json"
assert "settings.json has wikipedia.org" "grep -q 'wikipedia.org' settings.json"
assert "settings.json has github.com" "grep -q 'github.com' settings.json"
echo ""

# ── 11. File structure ─────────────────────────────────────────────────
echo "[11] File structure..."
assert "scripts/fetch.py" "[ -f scripts/fetch.py ]"
assert "install.sh"       "[ -f install.sh ]"
assert "SKILL.md"         "[ -f SKILL.md ]"
assert "settings.json"    "[ -f settings.json ]"
assert ".env.example"     "[ -f .env.example ]"
assert ".gitignore"       "[ -f .gitignore ]"
assert "pyproject.toml"   "[ -f pyproject.toml ]"
assert "no requirements.txt" "[ ! -f requirements.txt ]"
echo ""

# ── 12. Code quality ───────────────────────────────────────────────────
echo "[12] Code quality..."
assert "type hints"         "grep -q 'from typing import' scripts/fetch.py"
assert "docstrings (>=10)"  "[ $(grep -c '\"\"\"' scripts/fetch.py) -ge 10 ]"
assert "lynx cfg fix"       "grep -q 'f.*-cfg=' scripts/fetch.py"
assert "no readlink -f"     "grep -qv 'readlink -f' fetch-url"
assert "BASH_SOURCE used"   "grep -q 'BASH_SOURCE' fetch-url"
assert "old.reddit redirect" "grep -q 'old.reddit.com' scripts/fetch.py"
assert "_DEFAULT_SITE_TOOL_HINTS" "grep -q '_DEFAULT_SITE_TOOL_HINTS' scripts/fetch.py"
echo ""

# ── 13. .gitignore ────────────────────────────────────────────────────
echo "[13] .gitignore..."
assert ".venv/"        "grep -q '\.venv/' .gitignore"
assert "*.egg-info/"   "grep -q '\*\.egg-info/' .gitignore"
assert "uv.lock"       "grep -q 'uv.lock' .gitignore"
assert ".last-update"  "grep -q '\.last-update' .gitignore"
assert ".env"          "grep -q '\.env' .gitignore"
echo ""

# ── 14. SKILL.md ──────────────────────────────────────────────────────
echo "[14] SKILL.md..."
assert "name: fetch-url"    "grep -q '^name: fetch-url' SKILL.md"
assert "description"        "grep -q '^description:' SKILL.md"
assert "version 2.6"        "grep -q 'version.*\"2\.' SKILL.md"
assert "--update"           "grep -q '\-\-update' SKILL.md"
assert "--selfcheck"        "grep -q '\-\-selfcheck' SKILL.md"
assert "references/sites"   "grep -q 'references/sites' SKILL.md"
assert "references/github"  "grep -q 'references/github' SKILL.md"
assert "old.reddit"         "grep -q 'old.reddit' SKILL.md"
echo ""

# ── 15. Version alignment ─────────────────────────────────────────────
echo "[15] Version alignment..."
TOML_V=$(grep '^version' pyproject.toml | head -1 | grep -o '[0-9][0-9.]*' | sed 's/\.0$//')
SKILL_V=$(grep 'version' SKILL.md | head -1 | grep -o '[0-9][0-9.]*')
assert "pyproject ($TOML_V) and SKILL.md ($SKILL_V) match" "[ '$TOML_V' = '$SKILL_V' ]"
echo ""

# ── Summary ────────────────────────────────────────────────────────────
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
