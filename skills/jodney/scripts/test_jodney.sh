#!/usr/bin/env bash
# Test script for jodney skill - verifies installation and basic functionality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Jodney Skill Test ==="

# Check if jodney is available
if ! command -v jodney &> /dev/null; then
    echo "ERROR: jodney not found in PATH"
    echo ""
    echo "Install options:"
    echo "  1. Build from source: git clone https://github.com/simonw/jodney && cd jodney && go build -o jodney ."
    echo "  2. Install via uv: uv pip install jodney"
    exit 1
fi

echo "✓ jodney found: $(command -v jodney)"
echo ""

# Check Chrome/Chromium
CHROME_BIN="${ROD_CHROME_BIN:-/usr/bin/google-chrome}"
if command -v "$CHROME_BIN" &> /dev/null; then
    echo "✓ Chrome found: $CHROME_BIN"
else
    echo "⚠ Chrome not found at $CHROME_BIN"
    echo "  Set ROD_CHROME_BIN to your Chrome/Chromium path"
fi
echo ""

# Show jodney version/info
echo "=== Jodney Info ==="
jodney --version 2>/dev/null || jodney --help | head -3
echo ""

# Basic workflow test (optional - requires Chrome)
if [ "${RUN_INTEGRATION_TEST:-false}" = "true" ]; then
    echo "=== Integration Test ==="

    # Use local session for isolation
    echo "Starting Chrome..."
    jodney start --local

    echo "Opening example.com..."
    jodney open https://example.com
    jodney waitstable

    echo "Extracting title..."
    title=$(jodney title)
    echo "  Title: $title"

    echo "Taking screenshot..."
    jodney screenshot /tmp/jodney-test.png
    echo "  Saved: /tmp/jodney-test.png"

    echo "Stopping Chrome..."
    jodney stop

    # Cleanup (force remove all contents)
    rm -rf .jodney 2>/dev/null || true
    rm -f /tmp/jodney-test.png

    echo "✓ Integration test passed"
else
    echo "=== Skipping Integration Test ==="
    echo "Set RUN_INTEGRATION_TEST=true to run full browser test"
fi

echo ""
echo "=== Test Complete ==="
