#!/usr/bin/env bash
# install.sh — create the ~/.local/bin/viewimg launcher (Linux/macOS)
set -euo pipefail
mkdir -p "$HOME/.local/bin"
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/viewimg"
ln -sf "$SCRIPT" "$HOME/.local/bin/viewimg"
date +%s > "$(dirname "$SCRIPT")/.last-update"
echo "viewimg installed → $HOME/.local/bin/viewimg"
echo "Requires chafa (brew install chafa) for in-terminal rendering."
