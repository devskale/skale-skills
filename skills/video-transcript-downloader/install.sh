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

# Create venv + install yt-dlp — venv lives OUTSIDE the repo
# (pi package updates run `git clean -fdx` and would wipe an in-repo .venv).
ENV_DIR="${VTD_ENV_DIR:-$HOME/.cache/skale-skills/video-transcript-downloader}"
export VTD_ENV_DIR="$ENV_DIR"
if [ ! -x "$ENV_DIR/bin/yt-dlp" ] && [ ! -x "$ENV_DIR/Scripts/yt-dlp.exe" ]; then
    echo "Creating virtual environment in $ENV_DIR ..."
    uv venv "$ENV_DIR"
fi
echo "Installing yt-dlp..."
PY="$ENV_DIR/bin/python"
[ -x "$PY" ] || PY="$ENV_DIR/Scripts/python.exe"
uv pip install --python "$PY" yt-dlp

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
