#!/bin/bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

echo "Installing fetch-url skill..."

# Check for uv
if ! command -v uv &> /dev/null; then
    echo "uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Sync dependencies
echo "Syncing dependencies..."
uv sync

# Create symlink to launcher (not hardcoded path)
BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/fetch-url"
mkdir -p "$BIN_DIR"

if [ -L "$SYMLINK" ] || [ -f "$SYMLINK" ]; then
    if [ "$(readlink "$SYMLINK" 2>/dev/null)" != "$SKILL_DIR/fetch-url" ]; then
        echo "  Removing old wrapper at $SYMLINK"
        rm -f "$SYMLINK"
    fi
fi

if [ ! -L "$SYMLINK" ]; then
    ln -sf "$SKILL_DIR/fetch-url" "$SYMLINK"
    echo "  Created symlink: $SYMLINK → $SKILL_DIR/fetch-url"
fi

# Write update timestamp
date +%s > "$SKILL_DIR/.last-update"

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  fetch-url \"https://example.com\""
echo "  fetch-url \"https://reddit.com/r/python\""
echo ""
echo "Update:"
echo "  fetch-url --update"
echo "  fetch-url --selfcheck"
echo ""
echo "Credentials (optional, for API tool):"
echo "  credgoo add FETCH_URL_BEARER"
echo ""
echo "Optional browsers (for better results):"
echo "  brew install w3m lynx chawan"
