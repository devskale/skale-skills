#!/usr/bin/env bash
# Install the peep skill launcher → ~/.local/bin/peep
#
# Migration-safe: if ~/.local/bin/peep is already a REAL binary (installed
# via the old GitHub-download flow), it is moved to ~/.cache/peep-skill/peep-bin
# first and keeps working. The launcher then auto-updates it every 7 days.
set -e

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_HOME="$HOME/.cache/peep-skill"
BIN="$BIN_HOME/peep-bin"
TARGET_DIR="$HOME/.local/bin"
TARGET="$TARGET_DIR/peep"

mkdir -p "$BIN_HOME" "$TARGET_DIR"

is_our_launcher() {
    # Our wrapper sources this launcher; a real ELF/Mach-O binary does not.
    head -c 4 "$1" 2>/dev/null | grep -q '!#/dev/null' 2>/dev/null && return 1
    grep -q "peep launcher with symlink resolution" "$1" 2>/dev/null
}

# ── 1. Secure the binary ────────────────────────────────────────────────
if [ ! -x "$BIN" ] && [ -x "$TARGET" ]; then
    if ! is_our_launcher "$TARGET"; then
        echo "→ migrating existing binary $TARGET → $BIN"
        mv "$TARGET" "$BIN"
    fi
fi
if [ ! -x "$BIN" ]; then
    echo "→ no binary found — downloading latest release…"
    case "$(uname -s)/$(uname -m)" in
        Darwin/*)      ASSET="peep-darwin" ;;
        Linux/x86_64)  ASSET="peep-linux-x64" ;;
        *) ASSET="" ;;
    esac
    if [ -z "$ASSET" ]; then
        echo "✗ no prebuilt for $(uname -s)/$(uname -m) — build from source:" >&2
        echo "  git clone https://github.com/devskale/peep && cd peep && bun run build:binary" >&2
        echo "  then: cp peep $BIN" >&2
        exit 1
    fi
    curl -sfL "https://github.com/devskale/peep/releases/download/latest/$ASSET" -o "$BIN.tmp"
    chmod +x "$BIN.tmp" && mv "$BIN.tmp" "$BIN"
    echo "✓ binary installed: $BIN ($("$BIN" --version 2>/dev/null || echo '?'))"
fi

# ── 2. Launcher on PATH (SYMLINK — the launcher resolves it back to the
# skill dir for .last-update + SKILL.md; a copy would break that) ────────
ln -sf "$SKILL_DIR/peep" "$TARGET"
chmod +x "$TARGET"
echo "✓ launcher installed: $TARGET"
echo ""
echo "Verify: peep --selfcheck   ·   Force update: peep --update"
