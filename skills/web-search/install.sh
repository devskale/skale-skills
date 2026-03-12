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

# Create venv and install base dependencies
echo "Creating virtual environment..."
uv venv

echo "Installing dependencies..."
uv pip install requests

# Install credgoo from skale.dev
echo "Installing credgoo..."
uv pip install -r https://skale.dev/credgoo

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  ./search \"your query\""
echo "  ./search \"react hooks\" --site github.com --max 10"
echo ""
echo "Credentials:"
echo "  Duck API:  credgoo add WEB_SEARCH_BEARER"
echo "  SearXNG:   credgoo add searx  # URL@USERNAME@PASSWORD"
