#!/bin/bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

echo "Installing web-search skill..."
echo "  Skill dir: $SKILL_DIR"

# ── 1. Ensure uv is available ──────────────────────────────────────────────
if ! command -v uv &> /dev/null; then
    echo "  uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Make sure uv is in PATH even if just installed
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if ! command -v uv &> /dev/null; then
    echo "✗ uv not found in PATH after install. Add ~/.local/bin to PATH and retry."
    exit 1
fi

# ── 2. Install dependencies ────────────────────────────────────────────────
echo "  Syncing dependencies..."
uv sync

# ── 3. Create global symlink ───────────────────────────────────────────────
BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/web-search"
mkdir -p "$BIN_DIR"

# Remove stale symlink or file if it points elsewhere
if [ -L "$SYMLINK" ] || [ -f "$SYMLINK" ]; then
    if [ "$(readlink -f "$SYMLINK" 2>/dev/null || echo '')" != "$SKILL_DIR/search" ]; then
        echo "  Removing old symlink at $SYMLINK"
        rm -f "$SYMLINK"
    fi
fi

if [ ! -L "$SYMLINK" ]; then
    ln -sf "$SKILL_DIR/search" "$SYMLINK"
    echo "  Created symlink: $SYMLINK → $SKILL_DIR/search"
else
    echo "  Symlink already exists: $SYMLINK"
fi

# ── 4. Verify installation ─────────────────────────────────────────────────
echo "  Verifying..."
if OUTPUT=$("$SKILL_DIR/search" "test" -v 2>&1); then
    # Extract backend name from stderr output like "# Backend: duck"
    BACKEND=$(echo "$OUTPUT" | sed -n 's/.*Backend: \([a-z]*\).*/\1/p' || echo "unknown")
    echo "  ✓ web-search works (backend: $BACKEND)"
else
    echo "  ⚠ web-search installed but verification failed. Try running manually:"
    echo "    $SKILL_DIR/search \"test query\" -v"
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  web-search \"your query\"              # Search the web"
echo "  web-search \"cats\" --categories images # Image search"
echo "  web-search \"news\" --categories news    # News search"
echo "  web-search \"query\" -v                 # Verbose (show backend)"
echo ""
echo "Works out-of-the-box with public SearXNG instances."
echo ""
echo "Optional credentials for better results:"
echo ""
echo "  Duck API (advanced filters like --site, --filetype):"
echo "    credgoo add WEB_SEARCH_BEARER"
echo ""
echo "  Private SearXNG (better reliability):"
echo "    credgoo add searx"
echo "    # Format: URL@username@password"
