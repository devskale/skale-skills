#!/bin/bash
# rodney skill installer — downloads the platform binary from GitHub Releases
# (built by the fork's publish.yml CI), falls back to build-from-source.
# No Go toolchain required for the download path.
set -e
SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing rodney skill..."

BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/rodney"
mkdir -p "$BIN_DIR"

REPO="devskale/rodney"

# ── 1. Detect platform ────────────────────────────────────────────────────
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"   # darwin | linux
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "ERROR unsupported arch: $ARCH"; exit 1 ;;
esac
echo "  Platform: $OS/$ARCH"

# ── 2. Download the latest release binary ──────────────────────────────────
# Prefer an installed binary only if it's already current — otherwise refresh.
if command -v rodney >/dev/null 2>&1 && rodney --version >/dev/null 2>&1; then
    echo "  Current: $(rodney --version) at $(command -v rodney)"
fi

ASSET="rodney-$OS-$ARCH.tar.gz"
URL="https://github.com/$REPO/releases/latest/download/$ASSET"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "  Downloading $URL ..."
if curl -fsSL "$URL" -o "$TMP/$ASSET"; then
    tar -xzf "$TMP/$ASSET" -C "$TMP"
    BIN="$(find "$TMP" -type f -name rodney -perm +111 | head -1)"
    [ -n "$BIN" ] || BIN="$(find "$TMP" -type f -name rodney | head -1)"
    if [ -n "$BIN" ]; then
        mv "$BIN" "$LAUNCHER"
        chmod +x "$LAUNCHER"
    else
        echo "ERROR no rodney binary in tarball — falling back to source build"
        BUILD_FROM_SOURCE=1
    fi
else
    echo "NOTE download failed (no release asset for $OS/$ARCH?) — falling back to source build"
    BUILD_FROM_SOURCE=1
fi

# ── 3. Fallback: build from source (needs Go 1.21+) ────────────────────────
if [ "${BUILD_FROM_SOURCE:-0}" = "1" ]; then
    command -v go >/dev/null 2>&1 || { echo "ERROR no Go toolchain and no release binary — cannot install"; exit 1; }
    SRC="$HOME/src/rodney"
    if [ -d "$SRC" ]; then
        git -C "$SRC" pull --ff-only >/dev/null 2>&1 || true
    else
        git clone -b skale "https://github.com/$REPO.git" "$SRC"
    fi
    (cd "$SRC" && go build -ldflags="-s -w" -o "$LAUNCHER" .)
fi

# ── 4. Verify ──────────────────────────────────────────────────────────────
echo "  Verifying..."
"$LAUNCHER" --version
echo "  ✓ rodney installed at $LAUNCHER"

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) echo "  NOTE add ~/.local/bin to PATH to use 'rodney'" ;;
esac

echo ""
echo "✓ Installation complete!"
echo ""
echo "Usage:"
echo "  rodney start                  # headless Chrome session"
echo "  rodney open <url>             # navigate"
echo "  rodney --session <name> start # parallel session (own state + Chrome)"
echo "  rodney --help                 # everything else"
