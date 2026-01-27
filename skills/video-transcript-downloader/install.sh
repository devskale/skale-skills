#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "Installing dependencies for video-transcript-downloader..."

# Check for python3
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed."
    exit 1
fi

# Check/Install uv
if ! command -v uv &> /dev/null; then
    echo "uv is not installed. Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env 2>/dev/null || true
fi

# Create venv if missing
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
fi

# Install dependencies (yt-dlp)
source .venv/bin/activate
echo "Installing yt-dlp..."
uv pip install yt-dlp

# Install Node dependencies
if command -v pnpm &> /dev/null; then
    echo "Installing Node dependencies..."
    pnpm install
else
    echo "pnpm not found, skipping node dependencies (install manually if needed)..."
fi

echo "Installation complete!"
