#!/usr/bin/env bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

echo "Installing video-transcript-downloader..."

# Ensure ~/.local/bin exists
mkdir -p "$HOME/.local/bin"

# Check/Install uv
if ! command -v uv &> /dev/null; then
    echo "uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    else
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
fi

# Create venv + install yt-dlp
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
fi
echo "Installing yt-dlp..."
uv pip install yt-dlp

# Node dependencies
if command -v pnpm &> /dev/null; then
    echo "Installing Node dependencies (pnpm)..."
    pnpm install
elif command -v npm &> /dev/null; then
    echo "Installing Node dependencies (npm)..."
    npm install
else
    echo "Warning: No pnpm/npm found. Node deps may be missing."
fi

# Create symlink
ln -sf "$SKILL_DIR/vtd" "$HOME/.local/bin/vtd"
date +%s > "$SKILL_DIR/.last-update"

echo "Done. Use: vtd transcript --url 'https://...'"
