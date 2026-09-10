#!/bin/bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

# ── Dependency environment (kept OUTSIDE the repo) ──
# Same as the launcher: pi's package update runs `git clean -fdx`, which wipes
# any `.venv/` inside the package. Point uv at a cache dir so the skill stays
# pristine and updates never delete the virtualenv.
export UV_PROJECT_ENVIRONMENT="${UV_PROJECT_ENVIRONMENT:-$HOME/.cache/skale-skills/pdf2md}"

echo "Installing pdf2md skill..."

# Check for uv
if ! command -v uv &> /dev/null; then
    echo "uv not found. Installing..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Sync dependencies
echo "Syncing dependencies..."
uv sync

# Create symlink to launcher (not hardcoded path)
BIN_DIR="$HOME/.local/bin"
SYMLINK="$BIN_DIR/pdf2md"
mkdir -p "$BIN_DIR"

if [ -L "$SYMLINK" ] || [ -f "$SYMLINK" ]; then
    if [ "$(readlink "$SYMLINK" 2>/dev/null)" != "$SKILL_DIR/pdf2md" ]; then
        echo "  Removing old wrapper at $SYMLINK"
        rm -f "$SYMLINK"
    fi
fi

if [ ! -L "$SYMLINK" ]; then
    ln -sf "$SKILL_DIR/pdf2md" "$SYMLINK"
    echo "  Created symlink: $SYMLINK → $SKILL_DIR/pdf2md"
fi

# Write update timestamp
date +%s > "$SKILL_DIR/.last-update"

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  pdf2md document.pdf"
echo "  pdf2md scan.pdf --method llamaparse"
echo "  pdf2md doc.pdf --out doc.md"
echo ""
echo "Update:"
echo "  pdf2md --update"
echo "  pdf2md --selfcheck"
echo ""
echo "Credentials (bearer token for the pdf API — same as fetch-url's api tool):"
echo "  credgoo FETCH_URL_BEARER"
