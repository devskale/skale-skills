#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Installing Playwright browsers..."
npx playwright install chromium firefox webkit

echo "✓ Playwright browsers installed"
