#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Installing fetch-url skill..."

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
echo "  uv run scripts/fetch.py \"https://example.com\""
echo "  uv run scripts/fetch.py \"https://reddit.com/r/python\""
echo ""
echo "Credentials (optional, for API tool only):"
echo "  credgoo add FETCH_URL_BEARER"
echo ""
echo "Optional browsers (macOS/Linux):"
echo "  brew install w3m lynx chawan"
