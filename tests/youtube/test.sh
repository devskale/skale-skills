#!/usr/bin/env bash
set -e

# YouTube Skill Test Suite

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/youtube"

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
assert "version 2.x"        "grep -q 'version.*\"2\\.' SKILL.md"
echo ""

# ── 3. Launcher ───────────────────────────────────────────────────────
echo "[3] Launcher..."
assert "launcher executable" "[ -x youtube ]"
assert "launcher resolves enclosing git root" "grep -q 'GIT_ROOT=' youtube"
assert "auto-update guard uses git root" "grep -q 'GIT_ROOT/.git' youtube"
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
assert "mentions --captions (v2)" "grep -q '\-\-captions' /tmp/yt_help.txt"
assert "mentions --preset (v2)"   "grep -q '\-\-preset' /tmp/yt_help.txt"
rm -f /tmp/yt_help.txt
echo ""

# ── 9. selfcheck ─────────────────────────────────────────────────────
echo "[9] selfcheck..."
SELF=$(youtube --selfcheck 2>&1)
assert "shows version" "echo '$SELF' | grep -q 'youtube v'"
echo ""

# ── 10. Live search (resilient) ──────────────────────────────────────
echo "[10] Live search..."
RESULT=$(timeout 15 youtube "rick astley" --num 1 --any-length --stdout -v 2>&1) || true
if echo "$RESULT" | grep -q "Never Gonna Give You Up"; then
    PASS=$((PASS + 1))
else
    echo "  WARN: no result (API down?)"
    WARN=$((WARN + 1))
fi
assert "verbose shows instance" "echo '$RESULT' | grep -q 'Trying'"
echo ""

# ── 11. Instance cache ──────────────────────────────────────────────
echo "[11] Instance cache..."
# The cache is written opportunistically (after instance discovery) — trigger
# discovery if needed; absence is a skip, not a failure.
[ -f .instance-cache.json ] || timeout 30 youtube --discover >/dev/null 2>&1 || true
if [ -f .instance-cache.json ]; then
    assert "cache file exists" "[ -f .instance-cache.json ]"
    assert "cache has instances" "grep -q 'instances' .instance-cache.json"
else
    echo "  WARN: no instance cache (discovery unavailable?)"
    WARN=$((WARN + 1))
fi
echo ""

# ── 12. discover command ────────────────────────────────────────────
echo "[12] Discover command..."
DISC=$(timeout 30 youtube --discover 2>&1) || true
if echo "$DISC" | grep -q 'instance'; then
    PASS=$((PASS + 1))
else
    echo "  WARN: discovery slow/down"
    WARN=$((WARN + 1))
fi
echo ""

# ── 10b. v2: list save + subcommands ─────────────────────────────────
echo "[10b] v2 list save + subcommands..."
TMP=$(mktemp -d)
# live-content drift tolerance: loosen filters so the save-path is testable
# even when Invidious's current result mix has no fresh+long matches; || true so
# a hard network failure counts as a FAIL below instead of killing set -e.
(cd "$TMP" && timeout 25 youtube "linux kernel" --num 2 --pool 8 --fresh 36m --any-length 2>/dev/null) >/dev/null || true
assert "saves ./lists/<slug>.md" "ls '$TMP'/lists/*.md >/dev/null 2>&1"
assert "entry has youtube.com URL" "grep -q 'youtube.com/watch' '$TMP'/lists/*.md 2>/dev/null"
assert "channel --list runs" "youtube channel --list >/dev/null 2>&1"
assert "dedup errors without a list" "youtube dedup 2>&1 | grep -qi 'no target'"
rm -rf "$TMP"
echo ""

# ── 13. Unit tests (network-independent core logic) ──────────────
echo "[13] Unit tests (scoring/filtering/list parsing)..."
# cwd is skills/youtube (test.sh cd's there at the top); tests live two levels up.
UNIT_PY="$(cd ../../tests/youtube && pwd)/test_unit.py"
UNIT=$(python3 "$UNIT_PY" 2>&1) || true
if echo "$UNIT" | grep -q '^OK'; then
    PASS=$((PASS + 1))
else
    echo "  FAIL: unit tests"
    echo "$UNIT" | tail -20
    FAIL=$((FAIL + 1))
fi
assert "unit tests cover score_video" "grep -q 'def test_fav_boost' '$UNIT_PY'"
assert "unit tests cover passes_filters" "grep -q 'def test_too_old' '$UNIT_PY'"
echo ""

# ── Summary ──────────────────────────────────────────────────────────
echo ""
# ── 13. Top-up across hosts + fail-loud short-count (local fixture) ──
echo "[13] Top-up + fail-loud (local fixture)..."
# Local canned-Invidious fixture (no network): host A returns 6 videos of which
# only 2 pass the deep-preset filters; host B adds 3 more passing + 1 duplicate.
# Before the fix, one host's filtered remainder was returned silently even when
# < num. Now: results merge across hosts (dedup by videoId) until filters pass
# num, and a short-count prints a Note with the levers to loosen.
FIXT="$(mktemp -d)/fixture-server.py"
cat > "$FIXT" <<'FIXEOF'
import json, sys, time
from http.server import BaseHTTPRequestHandler, HTTPServer
MODE = sys.argv[2]
def vid(i, title, views, mins, months_old):
    return {"videoId": "vid%03d" % i, "title": title, "author": "chan%d" % i,
            "authorId": "UC%04d" % i, "viewCount": views,
            "lengthSeconds": mins * 60,
            "published": time.time() - months_old * 30 * 86400}
if MODE == "a":
    VIDS = [vid(1, "Stale Long Vid", 900000, 40, 30),
            vid(2, "Good Deep Vid A", 500000, 45, 2),
            vid(3, "Short Fresh Vid", 500000, 5, 2),
            vid(4, "Obscure Vid", 200, 40, 2),
            vid(5, "Good Deep Vid B", 400000, 60, 4),
            vid(6, "Ancient Classic", 5000000, 90, 40)]
else:
    VIDS = [vid(5, "Good Deep Vid B", 400000, 60, 4),
            vid(7, "Good Deep Vid C", 300000, 50, 1),
            vid(8, "Good Deep Vid D", 350000, 55, 6),
            vid(9, "Good Deep Vid E", 250000, 70, 9)]
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps(VIDS).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
FIXEOF
P1=18931; P2=18932
python3 "$FIXT" $P1 a >/dev/null 2>&1 & FXA=$!
python3 "$FIXT" $P2 b >/dev/null 2>&1 & FXB=$!
sleep 0.7
if ! kill -0 $FXA 2>/dev/null || ! kill -0 $FXB 2>/dev/null; then
    echo "  WARN: fixture ports busy — top-up test skipped"
    WARN=$((WARN+1))
else
    TU_OUT="$(YOUTUBE_HOSTS="http://localhost:$P1,http://localhost:$P2" youtube "fixture query" --stdout --num 5 2>"$FIXT.err")"
    TU_ERR="$(cat "$FIXT.err")"
    TU_N=$(printf '%s\n' "$TU_OUT" | grep -cE '^- \[' || true)
    TU_DUP=$(printf '%s\n' "$TU_OUT" | grep -c vid005 || true)
    assert "top-up: 5 asked, merged from 2 hosts -> 5 results" "[ "$TU_N" -eq 5 ]"
    assert "top-up: no Note when pool satisfies num" "! printf '%s' "$TU_ERR" | grep -q '^Note:'"
    assert "top-up: duplicate videoId counted once" "[ "$TU_DUP" -eq 1 ]"
    ONE_OUT="$(YOUTUBE_HOSTS="http://localhost:$P1" youtube "fixture query" --stdout --num 5 2>"$FIXT.err2")"
    ONE_ERR="$(cat "$FIXT.err2")"
    ONE_N=$(printf '%s\n' "$ONE_OUT" | grep -cE '^- \[' || true)
    assert "single host: 2 results (its passing remainder)" "[ "$ONE_N" -eq 2 ]"
    GOT_NOTE=$(printf '%s' "$ONE_ERR" | grep -c 'only 2/5 passed' || true)
    assert "short-count prints a Note with the count" "[ "$GOT_NOTE" -ge 1 ]"
    GOT_LEVER=$(printf '%s' "$ONE_ERR" | grep -c -- '--fresh' || true)
    assert "Note names the levers to loosen" "[ "$GOT_LEVER" -ge 1 ]"
fi
kill $FXA $FXB 2>/dev/null
echo ""

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
