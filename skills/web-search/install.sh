#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Installing web-search skill..."

# Check for uv
if ! command -v uv &> /dev/null; then
    echo "uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Sync dependencies from pyproject.toml (creates venv automatically)
echo "Syncing dependencies..."
uv sync

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  ./search \"your query\""
echo ""
echo "Works out-of-the-box with public SearXNG instances."
echo ""
echo "Optional credentials for better results:"
echo ""
echo "  Duck API (advanced filters):"
echo "    credgoo add WEB_SEARCH_BEARER"
echo ""
echo "  Private SearXNG (better reliability):"
echo "    credgoo add searx"
echo "    # Format: http://host@username@password"
