#!/usr/bin/env bash
# Test script for rodney skill - verifies installation and basic functionality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Rodney Skill Test ==="

# Check if rodney is available
if ! command -v rodney &> /dev/null; then
    echo "ERROR: rodney not found in PATH"
    echo ""
    echo "Install:"
    echo "  git clone git@github.com:devskale/rodney.git && cd rodney && go build -o ~/.local/bin/rodney ."
    exit 1
fi

echo "✓ rodney found: $(command -v rodney)"
echo ""

# Check Chrome/Chromium (cross-platform: macOS app bundle, Linux paths, or ROD_CHROME_BIN)
CHROME_BIN="${ROD_CHROME_BIN:-}"
if [ -z "$CHROME_BIN" ]; then
    for c in \
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "/Applications/Chromium.app/Contents/MacOS/Chromium" \
        "/usr/bin/google-chrome" \
        "/usr/bin/chromium" \
        "/usr/bin/chromium-browser" \
        "google-chrome" \
        "chromium"; do
        if command -v "$c" &>/dev/null || [ -x "$c" ]; then
            CHROME_BIN="$c"
            break
        fi
    done
fi
if [ -n "$CHROME_BIN" ]; then
    echo "✓ Chrome found: $CHROME_BIN"
else
    echo "⚠ No Chrome/Chromium found in common locations"
    echo "  Set ROD_CHROME_BIN to your Chrome/Chromium path"
fi
echo ""

# Show rodney version/info
rodney --version 2>/dev/null || true

echo "=== Rodney Self-Discovery (--help) ==="
if rodney --help &> /dev/null; then
    echo "✓ rodney --help works"
else
    echo "⚠ rodney --help failed — installed binary may be broken or too old"
fi
echo ""

# Basic workflow test (optional - requires Chrome)
if [ "${RUN_INTEGRATION_TEST:-false}" = "true" ]; then
    echo "=== Integration Test ==="

    # Use local session for isolation
    echo "Starting Chrome..."
    rodney start --local

    echo "Opening example.com..."
    rodney open https://example.com
    rodney waitstable

    echo "Extracting title..."
    title=$(rodney title)
    echo "  Title: $title"

    echo "Taking screenshot..."
    rodney screenshot /tmp/rodney-test.png
    echo "  Saved: /tmp/rodney-test.png"

    echo "Stopping Chrome..."
    rodney stop

    # Cleanup (force remove all contents)
    rm -rf .rodney 2>/dev/null || true
    rm -f /tmp/rodney-test.png

    echo "✓ Integration test passed"
else
    echo "=== Skipping Integration Test ==="
    echo "Set RUN_INTEGRATION_TEST=true to run full browser test"
fi

echo ""
echo "=== Test Complete ==="
