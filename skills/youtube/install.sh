#!/usr/bin/env bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

echo "Installing youtube skill..."

# Ensure ~/.local/bin exists
mkdir -p "$HOME/.local/bin"

# Create symlink
ln -sf "$SKILL_DIR/youtube" "$HOME/.local/bin/youtube"

echo "Done. Use: youtube \"search query\""
