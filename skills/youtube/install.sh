#!/usr/bin/env bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

# Dependency environment kept OUTSIDE the repo (pi's git clean -fdx on update
# wipes any .venv/ inside the package) — see agent-skills-best-practices.md.
export UV_PROJECT_ENVIRONMENT="${UV_PROJECT_ENVIRONMENT:-$HOME/.cache/skale-skills/youtube}"

echo "Installing youtube skill..."

# Ensure ~/.local/bin exists
mkdir -p "$HOME/.local/bin"

# Sync deps (into the cache env, not the repo)
if command -v uv &>/dev/null; then
    uv sync --quiet 2>/dev/null || true
fi

# Create symlink
ln -sf "$SKILL_DIR/youtube" "$HOME/.local/bin/youtube"

echo "Done. Use: youtube \"search query\""
