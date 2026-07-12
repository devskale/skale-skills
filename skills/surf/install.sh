#!/bin/bash
set -e
SKILL_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null)"
[ -z "$SKILL_DIR" ] && SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing surf skill..."

# macOS-only (AppleScript)
if [ "$(uname)" != "Darwin" ]; then
    echo "surf is macOS-only (uses AppleScript + Google Chrome). Aborting." >&2
    exit 1
fi
if [ ! -d "/Applications/Google Chrome.app" ]; then
    echo "Warning: Google Chrome.app not found in /Applications." >&2
fi

BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/surf"
mkdir -p "$BIN_DIR"
chmod +x "$SKILL_DIR/surf" "$SKILL_DIR/scripts/surf.sh" 2>/dev/null || true

if [ -L "$SYMLINK" ] || [ -f "$SYMLINK" ]; then
    if [ "$(readlink "$SYMLINK" 2>/dev/null)" != "$SKILL_DIR/surf" ]; then
        echo "  Removing old link at $SYMLINK"
        rm -f "$SYMLINK"
    fi
fi
if [ ! -L "$SYMLINK" ]; then
    ln -sf "$SKILL_DIR/surf" "$SYMLINK"
    echo "  Created symlink: $SYMLINK → $SKILL_DIR/surf"
fi

mkdir -p "$(dirname "$HOME/.config/surf/target")"
date +%s > "$SKILL_DIR/.last-update"

echo ""
echo "✓ Installation complete!"
echo ""
echo "One-time Chrome setup (enables JS control — click/fill/text/eval):"
echo "  surf setup"
echo "  …or manually: Chrome menu bar → View → Developer ▸ → Allow JavaScript from Apple Events (✓)"
echo ""
echo "Smoke test:"
echo "  surf tabs && surf here"
echo ""
echo "Usage:"
echo "  surf help"
