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
    echo "Install options:"
    echo "  1. Build from source: git clone https://github.com/simonw/rodney && cd rodney && go build -o rodney ."
    echo "  2. Install via uv: uv pip install rodney"
    exit 1
fi

echo "✓ rodney found: $(command -v rodney)"
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

# Show rodney version/info
echo "=== Rodney Info ==="
rodney --version 2>/dev/null || rodney --help | head -3
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
