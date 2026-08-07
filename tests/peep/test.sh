#!/usr/bin/env bash
set -e

# peep Skill Test Suite
#
# peep is a KNOWLEDGE skill — it has no scripts of its own; it drives the
# external `peep` binary. So the meaningful tests are:
#   1. File structure (SKILL.md + references present)
#   2. SKILL.md frontmatter + conventions
#   3. The documented commands/flags actually exist in the real `peep` CLI
#      (validated against `peep help`, when the binary is available)
#
# The CLI-surface checks are SKIPPED (not failed) when the `peep` binary is
# not installed, so the suite never hard-fails in an environment without peep.

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../skills/peep" && pwd)"
cd "$SKILL_DIR"

PASS=0
FAIL=0
SKIP=0

assert() {
    if eval "$2"; then
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: $1"
    fi
}

skip() {
    SKIP=$((SKIP + 1))
    echo "  SKIP: $1"
}

echo "=== Testing peep (knowledge skill) ==="
echo ""

# ── 1. File structure ─────────────────────────────────────────────────
echo "[1] File structure..."
assert "SKILL.md"            "[ -f SKILL.md ]"
assert "references/commands.md" "[ -f references/commands.md ]"
assert "references/data.md"  "[ -f references/data.md ]"
echo ""

# ── 2. SKILL.md frontmatter ───────────────────────────────────────────
echo "[2] SKILL.md frontmatter..."
assert "name: peep"          "grep -q '^name: peep' SKILL.md"
assert "description"          "grep -q '^description:' SKILL.md"
assert "version 0.x"          "grep -q 'version: \"0\\.' SKILL.md"
assert "license"              "grep -q '^license:' SKILL.md"
echo ""

# ── 3. SKILL.md body conventions ──────────────────────────────────────
echo "[3] SKILL.md body..."
assert "links references/commands.md" "grep -q 'references/commands.md' SKILL.md"
assert "links references/data.md"     "grep -q 'references/data.md' SKILL.md"
assert "no real tokens in SKILL.md"   "! grep -qiE '(auth_token|ct0)[[:space:]]*=[[:space:]]*[A-Za-z0-9]{20,}' SKILL.md"
assert "under 200 lines"              "[ \$(wc -l < SKILL.md) -lt 200 ]"
assert "has Setup/Install section"     "grep -q '## Setup / Install' SKILL.md"
assert "GitHub release binary URL"     "grep -q 'github.com/devskale/peep/releases/download/latest/peep-darwin' SKILL.md"
assert "install script URL"            "grep -q 'raw.githubusercontent.com/devskale/peep/main/scripts/install.sh' SKILL.md"
assert "no broken skale.dev URL"       "! grep -q 'skale.dev' SKILL.md"
assert "GitHub release link"           "grep -q 'github.com/devskale/peep/releases' SKILL.md"
assert "build-from-source (bun)"       "grep -q 'bun run build:binary' SKILL.md"
assert "verify command (--version)"     "grep -q 'peep --version' SKILL.md"
echo ""

# ── 4. CLI-surface validation (needs `peep` binary) ───────────────────
echo "[4] CLI surface (peep binary)..."
if ! command -v peep >/dev/null 2>&1; then
    skip "peep binary not installed — skipping CLI-surface checks"
    echo ""
    echo "=== Summary: $PASS passed, $FAIL failed, $SKIP skipped ==="
    [ "$FAIL" -eq 0 ]
    exit 0
fi

# Helper: assert a documented flag exists in a command's help output.
#   has_flag <command> <--flag>
has_flag() {
    peep help "$1" 2>&1 | grep -qE "(^| )$2([ ,]|$)"
}

# Documented commands exist at top level
for cmd in read thread replies search mentions home bookmarks likes news lists \
           list-timeline following followers user-tweets starred inbox research \
           about profile archive blocks mutes cache local-search query-ids whoami; do
    assert "command '$cmd' exists" "peep help 2>&1 | grep -qE \"^  ($cmd)(\\|trending)? \""
done

# Documented flags per command
assert "read --json"        "has_flag read --json"
assert "thread --max-pages" "has_flag thread --max-pages"
assert "thread --delay"     "has_flag thread --delay"
assert "replies --all"      "has_flag replies --all"
assert "search --all"       "has_flag search --all"
assert "search -n"          "has_flag search -n"
assert "mentions --user"    "has_flag mentions --user"
assert "home --following"   "has_flag home --following"
assert "bookmarks --folder-id" "has_flag bookmarks --folder-id"
assert "bookmarks --author-chain" "has_flag bookmarks --author-chain"
assert "bookmarks --include-parent" "has_flag bookmarks --include-parent"
assert "bookmarks --sort-chronological" "has_flag bookmarks --sort-chronological"
assert "likes --all"        "has_flag likes --all"
assert "news --ai-only"     "has_flag news --ai-only"
assert "news --with-tweets" "has_flag news --with-tweets"
assert "lists --member-of"  "has_flag lists --member-of"
assert "list-timeline --all" "has_flag list-timeline --all"
assert "following --user"   "has_flag following --user"
assert "followers --max-pages" "has_flag followers --max-pages"
assert "user-tweets --delay" "has_flag user-tweets --delay"
assert "starred --unread"   "has_flag starred --unread"
assert "starred --priority" "has_flag starred --priority"
assert "inbox --score"      "has_flag inbox --score"
assert "research --thread-depth" "has_flag research --thread-depth"
assert "research --no-live" "has_flag research --no-live"
assert "about --json"       "has_flag about --json"
assert "cache --stats"      "has_flag cache --stats"
assert "local-search --author" "has_flag local-search --author"
assert "query-ids --fresh"  "has_flag query-ids --fresh"

# Subcommands
assert "starred note"       "peep help starred 2>&1 | grep -qE '^  note '"
assert "starred tag"        "peep help starred 2>&1 | grep -qE '^  tag '"
assert "starred media"      "peep help starred 2>&1 | grep -qE '^  media '"
assert "archive find"       "peep help archive 2>&1 | grep -qE '^  find '"
assert "archive import"     "peep help archive 2>&1 | grep -qE '^  import '"
assert "profile replies"    "peep help profile 2>&1 | grep -qE '^  replies '"

# mutes must NOT advertise --import-file (blocks-only)
if peep help mutes 2>&1 | grep -q -- '--import-file'; then
    FAIL=$((FAIL + 1)); echo "  FAIL: mutes should NOT have --import-file (blocks-only)"
else
    PASS=$((PASS + 1))
fi

echo ""
echo "=== Summary: $PASS passed, $FAIL failed, $SKIP skipped ==="
[ "$FAIL" -eq 0 ]
