#!/bin/bash
set -e

# Ensure we're in the skill directory
cd "$(dirname "$0")"

echo "Installing dependencies for searxng-search skill..."

# Check for python3
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed."
    exit 1
fi

# Check for uv
if ! command -v uv &> /dev/null; then
    echo "uv is not installed. Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Add uv to path for current session if needed
    source $HOME/.cargo/env 2>/dev/null || true
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
fi

# Activate virtual environment
source .venv/bin/activate

# Install dependencies
echo "Installing credgoo..."
uv pip install -r https://skale.dev/credgoo

echo "Installation complete!"
echo "Please ensure your credentials for 'searx' are stored in credgoo."
