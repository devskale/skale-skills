#!/usr/bin/env bash
# link-agents.sh — make this repo's skills available to OTHER agents via the
# standard ~/.agents/skills directory (agentskills.io spec).
#
# Who reads ~/.agents/skills natively?
#   - pi           (~/.agents/skills is a default global skill location)
#   - zcode        (discovery order #3: explicit roots → ~/.zcode/skills →
#                  ~/.agents/skills → workspace .zcode/.agents → plugins)
#   - other spec-compliant agents (opencode & friends)
#
# What it does:
#   - symlinks every skill with a SKILL.md directly under skills/<name>/
#     into ~/.agents/skills/<name>  → $REPO/skills/<name>
#   - skills/deprecated/** is NEVER linked (zcode & co. have no manifest
#     exclusion — the only way to keep the archive out is not to link it)
#   - idempotent: correct links kept, stale links relinked, real copies
#     (user content) left untouched
#
# ⚠️ pi caveat (why install.sh gates this behind --agents / SKALE_LINK_AGENTS=1):
#   pi reads ~/.agents/skills natively and the pi package filter (seed-defaults
#   whitelist from install.sh) does NOT apply to skills found there — linking
#   activates every linked skill for pi too, on every machine this runs on.
#   Only opt in where other agents should get the skills.
#
# Usage:
#   scripts/link-agents.sh                 # → ~/.agents/skills
#   scripts/link-agents.sh /tmp/target     # explicit target dir (tests)
set -u

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENTS_DIR="${1:-$HOME/.agents/skills}"

mkdir -p "$AGENTS_DIR"

linked=0; kept=0; relinked=0; skipped=0; failed=0
for d in "$REPO_DIR"/skills/*/; do
    [ -f "${d}SKILL.md" ] || continue   # skills/deprecated/ has no top-level SKILL.md → skipped whole tree
    name="$(basename "$d")"
    target="$AGENTS_DIR/$name"
    source="$REPO_DIR/skills/$name"
    if [ -L "$target" ]; then
        if [ "$(readlink "$target")" = "$source" ]; then
            kept=$((kept+1))
        else
            rm -f "$target"
            if ln -s "$source" "$target"; then relinked=$((relinked+1)); else failed=$((failed+1)); echo "  ✗ relink failed: $name" >&2; fi
        fi
    elif [ -e "$target" ]; then
        skipped=$((skipped+1))
        echo "  · $name: exists as real copy — left untouched"
    else
        if ln -s "$source" "$target"; then linked=$((linked+1)); else failed=$((failed+1)); echo "  ✗ link failed: $name" >&2; fi
    fi
done

echo "link-agents: $AGENTS_DIR — linked=$linked kept=$kept relinked=$relinked untouched=$skipped failed=$failed"
[ "$failed" -eq 0 ]
