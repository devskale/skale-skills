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

# Sync dependencies from pyproject.toml (creates venv automatically)
echo "Syncing dependencies..."
uv sync

# Create wrapper in ~/.local/bin for global access
# cd into skill dir so relative paths (scripts/fetch.py) resolve correctly
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/fetch-url" << EOF
#!/usr/bin/env bash
cd "$SKILL_DIR" && exec uv run scripts/fetch.py "\$@"
EOF
chmod +x "$HOME/.local/bin/fetch-url"

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  fetch-url \"https://example.com\""
echo "  fetch-url \"https://reddit.com/r/python\""
echo ""
echo "Credentials (optional, for API tool only):"
echo "  credgoo add FETCH_URL_BEARER"
echo ""
echo "Optional browsers (macOS/Linux):"
echo "  brew install w3m lynx chawan"
