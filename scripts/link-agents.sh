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
#   whitelist from install.sh) does NOT apply to skills found there.
#
#   → pi-priority policy (built in): when linking to the real ~/.agents/skills,
#     the script ALSO ensures a `!skills/<name>/**` exclusion for every linked
#     skill in pi's user settings (${PI_SETTINGS:-~/.pi/agent/settings.json}).
#     pi then keeps loading these skills from its package copy (filtered,
#     versioned via `pi install`) instead of the links — no name collision,
#     no filter bypass — while zcode/claude/codex read the links unchanged.
#
#   Only opt in where other agents should get the skills.
#
# Usage:
#   scripts/link-agents.sh                 # → ~/.agents/skills
#   scripts/link-agents.sh /tmp/target     # explicit target dir (tests)
# Env:
#   PI_SETTINGS   — pi settings.json to manage exclusions in
#                   (default $HOME/.pi/agent/settings.json)
#   HOME          — overridden in tests to isolate both target and settings
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
[ "$failed" -eq 0 ] || exit 1

# ── pi-priority policy: keep pi on the package copy ──────────────────────
# Only when linking to the real standard dir (an explicit target arg means a
# test run — never touch live pi settings there).
if [ "$AGENTS_DIR" = "$HOME/.agents/skills" ] && command -v python3 >/dev/null 2>&1; then
    PI_SETTINGS="${PI_SETTINGS:-$HOME/.pi/agent/settings.json}"
    REPO_DIR="$REPO_DIR" PI_SETTINGS="$PI_SETTINGS" python3 - "$AGENTS_DIR" <<'PYEOF' && echo "pi-priority: package copy wins for pi (exclusions in $PI_SETTINGS)" || echo "  · pi-priority: no pi settings found — skipped (pi reads the links)"
import json, os, sys

settings_path = os.environ["PI_SETTINGS"]
repo_dir = os.environ["REPO_DIR"]
if not os.path.exists(settings_path):
    sys.exit(1)  # pi not installed → tell caller to skip

# every skill this repo links (mirrors the loop above)
names = sorted(
    name for name in os.listdir(os.path.join(repo_dir, "skills"))
    if os.path.isfile(os.path.join(repo_dir, "skills", name, "SKILL.md"))
)

d = json.load(open(settings_path))
skills = d.get("skills", [])
added = [n for n in names if "!skills/%s/**" % n not in skills]
if added:
    skills.extend("!skills/%s/**" % n for n in added)
    d["skills"] = skills
    json.dump(d, open(settings_path, "w"), indent=2)
    print("pi-priority: +%d exclusion(s): %s" % (len(added), ", ".join(added)))
else:
    print("pi-priority: all %d exclusions already in place" % len(names))
sys.exit(0)
PYEOF
fi
