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

# ── 3. Create global launcher (symlink to the repo launcher) ───────────────
# Symlink to the tracked `search` launcher (same pattern as fetch-url) so that
# --update / --selfcheck / auto-update behavior is consistent across installs.
# The launcher resolves its own SKILL_DIR via symlink, so no hardcoded path.
# Windows users use install.bat instead.
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/web-search"
mkdir -p "$BIN_DIR"

if [ -L "$LAUNCHER" ] || [ -f "$LAUNCHER" ]; then
    if [ "$(readlink "$LAUNCHER" 2>/dev/null)" != "$SKILL_DIR/search" ]; then
        echo "  Removing old launcher at $LAUNCHER"
        rm -f "$LAUNCHER"
    fi
fi

if [ ! -L "$LAUNCHER" ]; then
    ln -sf "$SKILL_DIR/search" "$LAUNCHER"
    echo "  Created symlink: $LAUNCHER → $SKILL_DIR/search"
fi

# ── 4. Verify installation ─────────────────────────────────────────────────
echo "  Verifying..."
if OUTPUT=$("$LAUNCHER" "test" -v 2>&1); then
    # Extract backend name from stderr output like "# Backend: duck"
    BACKEND=$(echo "$OUTPUT" | sed -n 's/.*Backend: \([a-z]*\).*/\1/p' || echo "unknown")
    echo "  ✓ web-search works (backend: $BACKEND)"
else
    echo "  ⚠ web-search installed but verification failed. Try running manually:"
    echo "    web-search \"test query\" -v"
    echo "    web-search --selfcheck   # (checks credgoo health too)"
fi

# ── 5. Write update timestamp ──────────────────────────────────────────────
date +%s > "$SKILL_DIR/.last-update"

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  web-search \"your query\"              # Search the web"
echo "  web-search \"cats\" --categories images # Image search"
echo "  web-search \"news\" --categories news    # News search"
echo "  web-search \"query\" -v                 # Verbose (show backend)"
echo ""
echo "Update / health:"
echo "  web-search --update                    # git pull + uv sync"
echo "  web-search --selfcheck                 # version + credgoo health"
echo ""
echo "Works out-of-the-box with public SearXNG instances."
echo ""
echo "Optional credentials for better results:"
echo ""
echo "  Install credgoo CLI first (from git, so it stays upgradeable):"
echo "    uv tool install \"credgoo @ git+https://github.com/devskale/python-openutils.git#subdirectory=packages/credgoo\""
echo "    credgoo --setup"
echo "    uv tool upgrade credgoo               # keep it current"
echo ""
echo "  Duck API (advanced filters like --site, --filetype):"
echo "    credgoo WEB_SEARCH_BEARER"
echo ""
echo "  Private SearXNG (better reliability):"
echo "    credgoo searx   # Should return: URL@username@password"
