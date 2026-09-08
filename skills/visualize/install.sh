#!/bin/bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

echo "Installing visualize skill..."

BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/visualize"
mkdir -p "$BIN_DIR"

if [ -L "$SYMLINK" ] || [ -f "$SYMLINK" ]; then
    if [ "$(readlink "$SYMLINK" 2>/dev/null)" != "$SKILL_DIR/visualize" ]; then
        echo "  Removing old wrapper at $SYMLINK"
        rm -f "$SYMLINK"
    fi
fi

if [ ! -L "$SYMLINK" ]; then
    ln -sf "$SKILL_DIR/visualize" "$SYMLINK"
    date +%s > "$SKILL_DIR/.last-update"
    echo "  Created symlink: $SYMLINK → $SKILL_DIR/visualize"
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  visualize open <file.html>      # open in browser"
echo "  visualize share <file.html>     # upload to throway, print URL"
echo "  visualize validate <file.html>  # check self-contained"
echo ""
echo "Requires: curl (for share). Optional: python3 (better URL parsing)."
