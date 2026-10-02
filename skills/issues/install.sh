#!/bin/bash
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SKILL_DIR"

echo "Installing issues skill..."

# ── 1. Global launcher (symlink to the tracked CLI) ─────────────────────────
# Symlink to the tracked `issues` CLI (same pattern as visualize/web-search) so
# --update / --selfcheck / auto-update behavior is consistent across installs.
# The CLI resolves its own SKILL_DIR via symlink, so no hardcoded path.
BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/issues"
mkdir -p "$BIN_DIR"

if [ -L "$LAUNCHER" ] || [ -f "$LAUNCHER" ]; then
    if [ "$(readlink "$LAUNCHER" 2>/dev/null)" != "$SKILL_DIR/issues" ]; then
        echo "  Removing old launcher at $LAUNCHER"
        rm -f "$LAUNCHER"
    fi
fi

if [ ! -L "$LAUNCHER" ]; then
    ln -sf "$SKILL_DIR/issues" "$LAUNCHER"
    date +%s > "$SKILL_DIR/.last-update"
    echo "  Created symlink: $LAUNCHER → $SKILL_DIR/issues"
fi

# ── 2. Verify ──────────────────────────────────────────────────────────────
echo "  Verifying..."
if "$LAUNCHER" board >/dev/null 2>&1; then
    echo "  ✓ issues works"
else
    echo "  NOTE issues board failed — no .handoff in cwd? Run from a repo with .handoff/ linked (issues init <project>)."
fi

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "  NOTE add ~/.local/bin to PATH to use 'issues'" ;;
esac

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  issues board                  # overview"
echo "  issues new <slug> [to]        # create"
echo "  issues todo                   # what's waiting on you"
echo "  issues --help                 # everything else"
