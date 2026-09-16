#!/usr/bin/env bash
set -e

# Fetch URL Skill Test Suite
# Tests the installed `fetch-url` command + source files

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/fetch-url"
SKILL_DIR="$(pwd)"

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
    WARN=$((WARN + 1))
fi
echo ""

# ── 6. Live: HN ────────────────────────────────────────────────────────
echo "[6] Live: Hacker News..."
RESULT=$(fetch-url "https://news.ycombinator.com/" 2>&1) || true
if echo "$RESULT" | grep -q "Hacker News"; then
    PASS=$((PASS + 1))
else
    echo "  WARN: no HN result (network?)"
    WARN=$((WARN + 1))
fi
echo ""

# ── 7. Live: Wikipedia ─────────────────────────────────────────────────
echo "[7] Live: Wikipedia..."
RESULT=$(fetch-url "https://en.wikipedia.org/wiki/Rust_(programming_language)" 2>&1) || true
if echo "$RESULT" | grep -qi "rust"; then
    PASS=$((PASS + 1))
else
    echo "  WARN: no Wikipedia result (network?)"
    WARN=$((WARN + 1))
fi
echo ""

# ── 8. Reddit redirect ─────────────────────────────────────────────────
echo "[8] Reddit redirect..."
STDERR=$(fetch-url "https://www.reddit.com/r/python/" -v 2>&1 1>/dev/null) || true
assert "redirects to old.reddit.com" "echo '$STDERR' | grep -q 'old.reddit.com'"
echo ""

# ── 9. is_valid_content logic ──────────────────────────────────────────
echo "[9] is_valid_content logic..."
cd "$SKILL_DIR"

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
assert "SKILL.md under 100 lines" "[ \"$(wc -l < SKILL.md | tr -d ' ')\" -le 99 ]"
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
TOML_V=$(grep '^version' pyproject.toml | head -1 | grep -o '[0-9][0-9.]*')
SKILL_V=$(grep 'version' SKILL.md | head -1 | grep -o '[0-9][0-9.]*')
assert "pyproject ($TOML_V) and SKILL.md ($SKILL_V) match" "[ '$TOML_V' = '$SKILL_V' ]"
echo ""

# ── Summary ────────────────────────────────────────────────────────────
echo ""
echo "=== Results ==="
echo "  Passed: $PASS"
# ── 16. Noise Module Tests ───────────────────────────────────────────────
echo "[16] Noise module..."

# Run noise/ tests (absoluter Pfad)
if python3 /Users/johannwaldherr/code/agents/skills/skale-skills/tests/fetch-url/noise/test_noise.py > /dev/null 2>&1; then
    NOISE_PASS=$(python3 /Users/johannwaldherr/code/agents/skills/skale-skills/tests/fetch-url/noise/test_noise.py 2>&1 | grep -c '✓')
    PASS=$((PASS + NOISE_PASS))
    echo "  ✓ Noise module tests ($NOISE_PASS passed)"
else
    FAIL=$((FAIL + 1))
    echo "  ❌ Noise module tests failed"
    python3 /Users/johannwaldherr/code/agents/skills/skale-skills/tests/fetch-url/noise/test_noise.py 2>&1 | head -20
fi
echo ""

# ── 17. Text Noise Cleaner Tests (Nav/Cookie-Rauschen, Issue
#      fetch-url-nav-cookie-noise) ─────────────────────────────────────
echo "[17] Text noise cleaner (nav/consent)..."

TEXTCLEAN="/Users/johannwaldherr/code/agents/skills/skale-skills/tests/fetch-url/noise/test_textclean.py"
if python3 "$TEXTCLEAN" > /dev/null 2>&1; then
    TC_PASS=$(python3 "$TEXTCLEAN" 2>&1 | grep -c '✓')
    PASS=$((PASS + TC_PASS))
    echo "  ✓ Text noise cleaner tests ($TC_PASS passed)"
else
    FAIL=$((FAIL + 1))
    echo "  ❌ Text noise cleaner tests failed"
    python3 "$TEXTCLEAN" 2>&1 | head -20
fi

# Fixtures vorhanden (Live-Fälle 2026-09-14, gekürzt)
assert "fixture claude-docs-nav"  "[ -f /Users/johannwaldherr/code/agents/skills/skale-skills/tests/fetch-url/fixtures/claude-docs-nav.txt ]"
assert "fixture w3c-wcag-nav"     "[ -f /Users/johannwaldherr/code/agents/skills/skale-skills/tests/fetch-url/fixtures/w3c-wcag-nav.txt ]"

# Cookie-Wall als Strong-Error-Pattern (w3.org via w3m/markdown)
COOKIEWALL=$(python3 -c "
import sys; sys.path.insert(0, 'scripts')
from fetch import is_valid_content
print('reject' if not is_valid_content('Refresh (360 sec)\nEnable JavaScript and cookies to continue') else 'pass')
") || true
assert "cookie wall rejected" "[ '$COOKIEWALL' = 'reject' ]"
echo ""

# ── 18. Live-Smoke: Nav-Rauschen im w3m-Fallback ──────────────────────
echo "[18] Live: nav-noise stripped (w3m)..."
RESULT=$(python3 scripts/fetch.py "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices" --tool w3m 2>&1) || true
if [ -n "$RESULT" ]; then
    if echo "$RESULT" | head -5 | grep -q 'alternate'; then
        FAIL=$((FAIL + 1))
        echo "  FAIL: Nav-Soup am Output-Anfang"
    else
        PASS=$((PASS + 1))
    fi
else
    echo "  WARN: kein w3m-Resultat (network?)"
    WARN=$((WARN + 1))
fi
echo ""

# ── Results ──────────────────────────────────────────────────────────────
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
