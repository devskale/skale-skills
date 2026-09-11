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

# ── 3. zcode (symlink skill dirs into ~/.zcode/skills) ──
ZCODE_DIR="$HOME/.zcode/skills"
if [ -d "$ZCODE_DIR" ]; then
    echo
    echo "── zcode ($ZCODE_DIR) ──"
    for d in skills/*/; do
        name=$(basename "$d")
        [ -f "${d}SKILL.md" ] || continue
        target="$ZCODE_DIR/$name"
        if [ -L "$target" ]; then
            echo "· $name: already linked"
        elif [ -e "$target" ]; then
            echo "· $name: exists as real copy — left untouched"
        else
            ln -s "$REPO_DIR/skills/$name" "$target" && echo "· $name: symlinked"
        fi
    done
fi

# ── 4. pi (package install/update) ──
echo
echo "── pi ──"
if command -v pi >/dev/null 2>&1; then
    if pi install git:github.com/devskale/skale-skills >/tmp/skale-install-pi.log 2>&1; then
        echo "· package installed/updated   (activate skills: pi config)"
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
