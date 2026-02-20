#!/bin/bash
set -e

# Ensure we're in the skill directory
cd "$(dirname "$0")"

echo "Installing dependencies for searxng-search skill..."

# Detect OS
IS_WINDOWS=false
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    IS_WINDOWS=true
fi

# Check for python3
if ! command -v python3 &> /dev/null; then
    if ! command -v python &> /dev/null; then
        echo "Error: python is not installed."
        exit 1
    fi
    PYTHON_CMD="python"
else
    PYTHON_CMD="python3"
fi

# Check for uv
if ! command -v uv &> /dev/null; then
    echo "uv is not installed. Installing uv..."
    if [ "$IS_WINDOWS" = true ]; then
        # Windows: use PowerShell installer
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
        # Add to PATH for current session
        export PATH="$USERPROFILE/.local/bin:$PATH"
        export PATH="$HOME/.local/bin:$PATH"
    else
        # Linux/Mac
        curl -LsSf https://astral.sh/uv/install.sh | sh
        source $HOME/.cargo/env 2>/dev/null || true
    fi
fi

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
fi

# Install dependencies with correct Python path
echo "Installing credgoo..."
if [ "$IS_WINDOWS" = true ]; then
    # Windows: use Scripts/python.exe
    uv pip install --python .venv/Scripts/python.exe -r https://skale.dev/credgoo
else
    # Linux/Mac: use bin/python
    uv pip install --python .venv/bin/python -r https://skale.dev/credgoo
fi

echo ""
echo "Installation complete!"
echo "Please ensure your credentials for 'searx' are stored in credgoo."
echo "Format: URL@USERNAME@PASSWORD"
echo "Example: https://neusiedl.duckdns.org:8002@searxng@searxng23"
