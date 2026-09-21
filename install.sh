#!/usr/bin/env bash
# skale-skills — one-command installer (idempotent, safe to re-run)
#
#   ./install.sh
#
# 1. installs uv (shared runner for the python skills)
# 2. runs every skills/*/install.sh  → global commands in ~/.local/bin
# 3. symlinks skill dirs into ~/.zcode/skills (never touches real copies)
# 4. installs/updates the pi package (if pi is present) + activation hint
# 5. reminds about credgoo (API keys)
set -u
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "skale-skills installer"
echo "  repo: $REPO_DIR"
echo

# ── 1. uv (shared dependency runner for the python skills) ──
if ! command -v uv >/dev/null 2>&1; then
    echo "· uv not found — installing…"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# ── 2. per-skill installers → global commands in ~/.local/bin ──
echo "── Skills (global commands in ~/.local/bin) ──"
for installer in skills/*/install.sh; do
    [ -f "$installer" ] || continue
    name=$(basename "$(dirname "$installer")")
    printf "· %-28s" "$name"
    if bash "$installer" >/tmp/skale-install-last.log 2>&1; then
        echo "✓"
    else
        echo "✗ FAILED — details: bash $installer"
    fi
done
echo "  (d2, peep, improve-ux are knowledge skills; figure needs node — nothing to install)"
echo "  (rodney: uv tool install per guides/rodney-setup.md)"

# ── 3. other agents — which agents should get our skills? ──
# Interactive by default (real terminal); non-interactive fallbacks:
#   ./install.sh --agents    or SKALE_LINK_AGENTS=1 → standard dir (~/.agents/skills)
#   ./install.sh --no-agents or SKALE_LINK_AGENTS=0 → none (pi only)
# The choice is recorded in ~/.config/skale-skills/link-agents.conf and reused
# on re-runs (delete the file — or pass a flag — to change it).
# pi caveat: skills discovered via ~/.agents/skills bypass the pi package
# filter (install.sh seed-defaults whitelist) — they are active for pi too.
AGENTS_STATE_DIR="$HOME/.config/skale-skills"
AGENTS_STATE="$AGENTS_STATE_DIR/link-agents.conf"
AGENTS_CHOICE=""

if [ "${1:-}" = "--agents" ] || [ "${SKALE_LINK_AGENTS:-}" = "1" ]; then
    AGENTS_CHOICE="$HOME/.agents/skills"              # non-interactive: standard dir
elif [ "${1:-}" = "--no-agents" ] || [ "${SKALE_LINK_AGENTS:-}" = "0" ]; then
    AGENTS_CHOICE=""                                  # non-interactive: none
elif [ -f "$AGENTS_STATE" ]; then
    AGENTS_CHOICE="$(tr '\n' ' ' < "$AGENTS_STATE")"  # recorded choice (reuse, no re-ask)
    AGENTS_CHOICE="${AGENTS_CHOICE% }"
else
    # interactive pick — only with a real terminal
    AGENT_PATHS=("$HOME/.agents/skills" "$HOME/.zcode/skills" "$HOME/.claude/skills" "$HOME/.codex/skills")
    AGENT_LABELS=("standard ~/.agents/skills (zcode, opencode, spec-compliant; pi reads it too)"
                  "~/.zcode/skills (zcode native)"
                  "~/.claude/skills (Claude Code)"
                  "~/.codex/skills (Codex)")
    echo
    echo "── Expose skills to other agents? ──"
    i=0
    while [ "$i" -lt "${#AGENT_PATHS[@]}" ]; do
        mark=""
        [ -d "${AGENT_PATHS[$i]}" ] && mark="  [dir exists]"
        echo "  $((i+1))) ${AGENT_LABELS[$i]}$mark"
        i=$((i+1))
    done
    echo "  0) none — pi only (default)"
    answer=""
    [ -t 0 ] && read -r -p "Which agents? (e.g. '1 3', Enter = none): " answer
    for n in $answer; do
        case "$n" in
            1|2|3|4) idx=$((n-1)); AGENTS_CHOICE="$AGENTS_CHOICE ${AGENT_PATHS[$idx]}" ;;
        esac
    done
    AGENTS_CHOICE="${AGENTS_CHOICE# }"
    mkdir -p "$AGENTS_STATE_DIR"
    printf '%s\n' $AGENTS_CHOICE > "$AGENTS_STATE"   # unquoted: one path per line; empty = none
    echo "  choice recorded in $AGENTS_STATE (delete it or pass --agents/--no-agents to change)"
fi

if [ -n "$AGENTS_CHOICE" ]; then
    for t in $AGENTS_CHOICE; do
        echo
        echo "── other agents → $t ──"
        bash scripts/link-agents.sh "$t"
    done
else
    echo
    echo "── other agents: none (pi only; re-run ./install.sh to choose, or use --agents) ──"
fi

# ── 4. pi (package install/update) ──
echo
echo "── pi ──"
if command -v pi >/dev/null 2>&1; then
    if pi install git:github.com/devskale/skale-skills >/tmp/skale-install-pi.log 2>&1; then
        echo "· package installed/updated   (activate skills: pi config)"
        # Seed the minimal default activation (web-search + fetch-url) on fresh
        # installs — pi checks ALL skills by default otherwise. No-op when a
        # skills filter already exists (respects your customization).
        bash scripts/skill-filter.sh seed-defaults || true
    else
        echo "! pi install failed — run manually: pi install git:github.com/devskale/skale-skills"
    fi
else
    echo "· pi not found — to serve these skills from pi:"
    echo "    pi install git:github.com/devskale/skale-skills && pi config"
fi

# ── 5. credentials ──
echo
echo "── Credentials (API keys via credgoo) ──"
if command -v credgoo >/dev/null 2>&1; then
    echo "· credgoo present — e.g. credgoo FETCH_URL_BEARER (see docs/credgoo.md)"
else
    echo "· credgoo missing:"
    echo "    uv tool install \"credgoo @ git+https://github.com/devskale/python-openutils.git#subdirectory=packages/credgoo\""
fi

echo
echo "✓ done"
