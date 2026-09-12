#!/bin/bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

echo "Installing improve-ux skill..."

BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/improve-ux"
mkdir -p "$BIN_DIR"

if [ -L "$SYMLINK" ] || [ -f "$SYMLINK" ]; then
    if [ "$(readlink "$SYMLINK" 2>/dev/null)" != "$SKILL_DIR/improve-ux" ]; then
        echo "  Removing old wrapper at $SYMLINK"
        rm -f "$SYMLINK"
    fi
fi

if [ ! -L "$SYMLINK" ]; then
    ln -sf "$SKILL_DIR/improve-ux" "$SYMLINK"
    date +%s > "$SKILL_DIR/.last-update"
    echo "  Created symlink: $SYMLINK → $SKILL_DIR/improve-ux"
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  improve-ux discover            # web-search new UX reference sites"
echo "  improve-ux add <url> \"<focus>\" # verify + append a site to SITES.md"
echo ""
echo "The knowledge workflow (routing, grounding, verify, ledger) lives in SKILL.md."
echo "Requires: web-search (sibling skill), python3, curl. Optional: peep (--x)."
