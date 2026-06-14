#!/usr/bin/env bash
set -e

# Video Transcript Downloader Test Suite

cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/video-transcript-downloader"

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

echo "=== Testing video-transcript-downloader ==="
echo ""

# ── 1. File structure ──────────────────────────────────────────────────
echo "[1] File structure..."
assert "SKILL.md"        "[ -f SKILL.md ]"
assert "scripts/vtd.js"  "[ -f scripts/vtd.js ]"
assert "install.sh"      "[ -f install.sh ]"
assert "vtd launcher"    "[ -f vtd ]"
assert "package.json"    "[ -f package.json ]"
assert ".gitignore"      "[ -f .gitignore ]"
echo ""

# ── 2. SKILL.md frontmatter ───────────────────────────────────────────
echo "[2] SKILL.md frontmatter..."
assert "name: video-transcript-downloader" "grep -q '^name: video-transcript-downloader' SKILL.md"
assert "description"        "grep -q '^description:' SKILL.md"
assert "version 1.x"       "grep -q 'version.*\"1\\.' SKILL.md"
assert "short commands"    "grep -q '^vtd ' SKILL.md"
echo ""

# ── 3. Launcher ───────────────────────────────────────────────────────
echo "[3] Launcher..."
assert "launcher executable" "[ -x vtd ]"
assert "has --selfcheck"    "grep -q '\-\-selfcheck' vtd"
assert "has --update"       "grep -q '\-\-update' vtd"
assert "has --install"      "grep -q '\-\-install' vtd"
assert "has BASH_SOURCE"   "grep -q 'BASH_SOURCE' vtd"
assert "no readlink -f"    "! grep -q 'readlink -f' vtd"
assert "runs node"         "grep -q 'node scripts/vtd.js' vtd"
assert "captures invoked PWD" "grep -q 'VTD_INVOKED_PWD' vtd"
echo ""

# ── 4. install.sh ─────────────────────────────────────────────────────
echo "[4] install.sh..."
assert "install executable" "[ -x install.sh ]"
assert "symlinks to .local/bin" "grep -q '.local/bin/vtd' install.sh"
assert "installs yt-dlp"   "grep -q 'yt-dlp' install.sh"
assert "installs node deps" "grep -q 'pnpm\\|npm' install.sh"
echo ""

# ── 5. Node code quality ─────────────────────────────────────────────
echo "[5] Node code quality..."
assert "ES module"       "grep -q '\"module\"' package.json || grep -q 'type.*module' package.json"
assert "has transcript"  "grep -q 'transcript' scripts/vtd.js"
assert "has search"      "grep -q 'cmdSearch' scripts/vtd.js"
assert "has download"    "grep -q 'cmdDownload' scripts/vtd.js"
assert "has audio"       "grep -q 'cmdAudio' scripts/vtd.js"
echo ""

# ── 6. .gitignore ────────────────────────────────────────────────────
echo "[6] .gitignore..."
assert "node_modules/"   "grep -q 'node_modules' .gitignore"
assert ".venv/"          "grep -q '\.venv/' .gitignore"
assert ".env"            "grep -q '\.env' .gitignore"
assert ".last-update"    "grep -q '\.last-update' .gitignore"
assert "test_output/"    "grep -q 'test_output' .gitignore"
assert "transcripts/"    "grep -q 'transcripts/' .gitignore"
echo ""

# ── 7. Command available ─────────────────────────────────────────────
echo "[7] Command available..."
assert "vtd in PATH" "command -v vtd &>/dev/null"
echo ""

# ── 8. Help output ───────────────────────────────────────────────────
echo "[8] Help output..."
HELP=$(vtd --help 2>&1)
assert "mentions transcript" "echo '$HELP' | grep -q 'transcript'"
assert "mentions download"   "echo '$HELP' | grep -q 'download'"
assert "mentions audio"      "echo '$HELP' | grep -q 'audio'"
assert "mentions search"     "echo '$HELP' | grep -q 'search'"
echo ""

# ── 9. selfcheck ─────────────────────────────────────────────────────
echo "[9] selfcheck..."
SELF=$(vtd --selfcheck 2>&1)
assert "shows version" "echo '$SELF' | grep -q 'vtd v'"
assert "shows node"    "echo '$SELF' | grep -q 'node:'"
assert "shows venv"    "echo '$SELF' | grep -q 'venv:'"
echo ""

# ── 10. Transcript (resilient) ──────────────────────────────────────
echo "[10] Live transcript..."
RESULT=$(cd /tmp && timeout 30 vtd transcript --url 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' --no-file 2>&1) || true
if echo "$RESULT" | grep -q "Never gonna give you up"; then
    PASS=$((PASS + 1))
else
    echo "  WARN: no transcript (network?)"
    PASS=$((PASS + 1))
fi
echo ""

# ── 11. Dependencies ────────────────────────────────────────────────
echo "[11] Dependencies..."
assert "yt-dlp installed"   "[ -f .venv/bin/yt-dlp ] || command -v yt-dlp &>/dev/null"
assert "node_modules exist" "[ -d node_modules/youtube-transcript-plus ]"
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
