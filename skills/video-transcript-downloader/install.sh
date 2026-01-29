#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Installing dependencies for video-transcript-downloader..."

# Check/Install uv
if ! command -v uv &> /dev/null; then
    echo "uv is not installed. Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # Ensure uv is in PATH for this session
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    else
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
fi

echo "Using uv to manage Python environment..."

# Create venv if missing
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
fi

# Install dependencies (yt-dlp)
echo "Installing yt-dlp..."
# uv automatically detects the .venv in the current directory
uv pip install yt-dlp

# Install Node dependencies
if command -v pnpm &> /dev/null; then
    echo "Installing Node dependencies with pnpm..."
    pnpm install
elif command -v npm &> /dev/null; then
    echo "pnpm not found, using npm..."
    npm install
else
    echo "Warning: Neither pnpm nor npm found. Node dependencies might be missing."
fi

echo "Installation complete!"
