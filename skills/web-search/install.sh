#!/bin/bash

set -e

# Ensure we're in the skill directory
cd "$(dirname "$0")"

echo "Installing dependencies for web-search skill..."

# Check for python
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    echo "Error: python is not installed."
    exit 1
fi

# Check for uv
if ! command -v uv &> /dev/null; then
    echo "uv is not installed. Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install uv."
        exit 1
    fi
    # Source uv for current session
    export PATH="$HOME/.local/bin:$PATH"
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create virtual environment."
        exit 1
    fi
fi

# Install dependencies from requirements.txt
echo "Installing dependencies..."
uv pip install -r requirements.txt

# Install credgoo from skale.dev if not already installed
echo "Ensuring credgoo is available..."
if ! python -c "import credgoo" 2>/dev/null; then
    echo "Installing credgoo from skale.dev..."
    uv pip install -r https://skale.dev/credgoo
fi

echo ""
echo "Installation complete!"
echo ""
echo "Usage:"
echo "  ./search.sh \"your query\""
echo "  ./search.sh \"react hooks\" --site github.com"
echo ""
echo "Configuration (optional):"
echo "  - DuckDuckGo: Set WEB_SEARCH_BEARER environment variable"
echo "  - SearXNG: Configure 'searx' in credgoo (URL@USERNAME@PASSWORD)"
echo ""
