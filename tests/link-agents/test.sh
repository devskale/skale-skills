#!/usr/bin/env bash
# link-agents.sh test suite
#   bash tests/link-agents/test.sh
# Tests scripts/link-agents.sh against a TEMP TARGET dir — never the live
# ~/.agents/skills. Also checks the install.sh opt-in wiring.
set -uo pipefail
cd "$(dirname "$0")/../.."

SCRIPT=scripts/link-agents.sh
PASS=0; FAIL=0; WARN=0

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN+1)); echo "  WARN (skipped honestly): $1" >&2; }

echo "link-agents tests"
echo "-----------------"

# ── structure ──
[ -f "$SCRIPT" ] && ok || bad "$SCRIPT missing"
chmod +x "$SCRIPT" 2>/dev/null
[ -x "$SCRIPT" ] && ok || bad "$SCRIPT not executable"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TARGET="$TMP/agents-skills"

# ── first run: links every non-deprecated skill ──
bash "$SCRIPT" "$TARGET" >/dev/null 2>&1 && ok || bad "first run failed"
n_linked=0
for d in skills/*/; do
    name="$(basename "$d")"
    [ -f "${d}SKILL.md" ] || continue
    n_linked=$((n_linked+1))
    [ -L "$TARGET/$name" ] && ok || bad "$name not linked"
    [ "$(readlink "$TARGET/$name" 2>/dev/null)" = "$(pwd)/skills/$name" ] && ok || bad "$name points wrong: $(readlink "$TARGET/$name")"
done
[ "$n_linked" -ge 10 ] && ok || bad "expected many skills, got $n_linked"

# ── deprecated skills are NEVER linked ──
[ ! -e "$TARGET/deprecated" ] && ok || bad "deprecated tree must never be linked"
for name in viewimg todo readme-write agent-skill-creator; do
    [ ! -e "$TARGET/$name" ] && ok || bad "deprecated skill $name must not be linked"
done

# ── idempotent: second run keeps links, relinks nothing ──
out2="$(bash "$SCRIPT" "$TARGET" 2>&1)"
echo "$out2" | grep -q "relinked=0 " && ok || bad "second run should relink nothing: $out2"
echo "$out2" | grep -q "linked=0 " && ok || bad "second run should link nothing new: $out2"

# ── stale link gets relinked ──
rm -f "$TARGET/web-search"
ln -s "/nonexistent/old/path/web-search" "$TARGET/web-search"
bash "$SCRIPT" "$TARGET" >/dev/null 2>&1
[ "$(readlink "$TARGET/web-search" 2>/dev/null)" = "$(pwd)/skills/web-search" ] && ok || bad "stale link not relinked"

# ── real copy (user content) left untouched ──
rm -f "$TARGET/d2"
mkdir -p "$TARGET/d2"
echo "user content" > "$TARGET/d2/SKILL.md"
bash "$SCRIPT" "$TARGET" >/dev/null 2>&1
[ ! -L "$TARGET/d2" ] && ok || bad "real copy must not be replaced by a symlink"
grep -q "user content" "$TARGET/d2/SKILL.md" && ok || bad "real copy content was modified"

# ── install.sh wiring: interactive choice + non-interactive fallbacks ──
grep -q 'scripts/link-agents.sh' install.sh && ok || bad "install.sh must call link-agents.sh"
grep -q 'SKALE_LINK_AGENTS' install.sh && ok || bad "install.sh must support SKALE_LINK_AGENTS=1/0"
grep -q -- '"--agents"' install.sh && ok || bad "install.sh must accept --agents flag"
grep -q -- '"--no-agents"' install.sh && ok || bad "install.sh must accept --no-agents flag"
grep -q 'Which agents?' install.sh && ok || bad "install.sh must ask interactively which agents to include"
grep -q '\[ -t 0 \]' install.sh && ok || bad "install.sh must TTY-guard the read (no hang in CI/pipes)"
grep -q 'link-agents.conf' install.sh && ok || bad "install.sh must record the agent choice for re-runs"
grep -q '.agents/skills' install.sh && grep -q '.zcode/skills' install.sh && grep -q '.claude/skills' install.sh && grep -q '.codex/skills' install.sh && ok || bad "install.sh menu must offer agents/standard, zcode, claude, codex"
grep -q 'deprecated' scripts/link-agents.sh && ok || bad "link-agents.sh must document the deprecated-exclusion guarantee"

# ── zcode reads ~/.agents/skills natively (documented) ──
grep -qi 'agents/skills' docs/zcode-plugin.md && ok || bad "docs/zcode-plugin.md should reference the standard dir"

echo ""
echo "PASS=$PASS FAIL=$FAIL WARN=$WARN"
[ "$FAIL" -eq 0 ]
