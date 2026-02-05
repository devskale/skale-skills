#!/usr/bin/env bash
set -e

# Web Search Skill Test Script
# Tests basic functionality of the web-search skill

# Determine skill directory (tests/web-search -> ../../skills/web-search)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/../../skills/web-search" && pwd)"
export WEB_SEARCH_BEARER="test_token_for_testing"

echo "Testing web-search skill..."
echo "Skill directory: $SKILL_DIR"
echo ""

cd "$SKILL_DIR"

# Test 1: Check that the script exists and is executable
echo "Test 1: Checking script exists..."
if [ ! -f "search.py" ]; then
    echo "ERROR: search.py not found"
    exit 1
fi
echo "✓ search.py exists"
echo ""

# Test 2: Check help message works
echo "Test 2: Testing help message..."
HELP_OUTPUT=$(uv run search.py --help 2>&1)
if ! echo "$HELP_OUTPUT" | grep -q "Search the web using DuckDuckGo"; then
    echo "ERROR: Help message not working correctly"
    echo "$HELP_OUTPUT"
    exit 1
fi
echo "✓ Help message works"
echo ""

# Test 3: Check required arguments
echo "Test 3: Testing required query argument..."
if uv run search.py 2>&1 | grep -q "required: query"; then
    echo "✓ Query argument is required"
else
    echo "✗ Query argument check failed"
    exit 1
fi
echo ""

# Test 4: Check that --api-url flag exists
echo "Test 4: Testing --api-url flag..."
if echo "$HELP_OUTPUT" | grep -q "\-\-api-url"; then
    echo "✓ --api-url flag exists"
else
    echo "✗ --api-url flag not found"
    exit 1
fi
echo ""

# Test 5: Check that --timeout flag exists
echo "Test 5: Testing --timeout flag..."
if echo "$HELP_OUTPUT" | grep -q "\-\-timeout"; then
    echo "✓ --timeout flag exists"
else
    echo "✗ --timeout flag not found"
    exit 1
fi
echo ""

# Test 6: Check backend options
echo "Test 6: Testing backend options..."
BACKEND_OPTIONS="auto, all, bing, brave, duckduckgo, google, mojeek, yandex, yahoo, wikipedia"
for backend in $BACKEND_OPTIONS; do
    if ! echo "$HELP_OUTPUT" | grep -q "$backend"; then
        echo "✗ Backend option '$backend' not found"
        exit 1
    fi
done
echo "✓ All backend options present"
echo ""

# Test 7: Check that Python script has type hints
echo "Test 7: Checking for type hints..."
if grep -q "from typing import" "search.py"; then
    echo "✓ Type hints imports present"
else
    echo "✗ Type hints imports not found"
    exit 1
fi
echo ""

# Test 8: Check imports are properly sorted (comments)
echo "Test 8: Checking import organization..."
if grep -q "# Standard library imports" "search.py" && \
   grep -q "# Third-party imports" "search.py"; then
    echo "✓ Imports are properly organized"
else
    echo "✗ Import organization comments missing"
    exit 1
fi
echo ""

# Test 9: Check docstrings exist
echo "Test 9: Checking for docstrings..."
if ! grep -q '"""' "search.py"; then
    echo "✗ Docstrings not found"
    exit 1
fi
DOCSTRING_COUNT=$(grep -c '"""' "search.py")
if [ "$DOCSTRING_COUNT" -lt 6 ]; then
    echo "✗ Insufficient docstrings (found $DOCSTRING_COUNT, expected at least 6)"
    exit 1
fi
echo "✓ Docstrings present (found $DOCSTRING_COUNT)"
echo ""

# Test 10: Verify SKILL.md has required YAML frontmatter
echo "Test 10: Checking SKILL.md frontmatter..."
if ! grep -q "^name: web-search" "SKILL.md"; then
    echo "✗ SKILL.md missing 'name' in frontmatter"
    exit 1
fi
if ! grep -q "^description:" "SKILL.md"; then
    echo "✗ SKILL.md missing 'description' in frontmatter"
    exit 1
fi
echo "✓ SKILL.md has proper frontmatter"
echo ""

# Test 11: Check credgoo support in code
echo "Test 11: Checking credgoo support..."
if ! grep -q "credgoo" "search.py"; then
    echo "✗ Credgoo support not found in code"
    exit 1
fi
echo "✓ Credgoo support present"
echo ""

# Test 12: Verify .env mentions credgoo
echo "Test 12: Checking .env.example for credgoo documentation..."
if ! grep -q "credgoo" ".env.example"; then
    echo "✗ .env.example missing credgoo documentation"
    exit 1
fi
echo "✓ .env.example documents credgoo"
echo ""

echo "All tests passed!"
echo ""
echo "Note: The API test was skipped as it requires a valid bearer token."
echo "To test the actual API functionality, set WEB_SEARCH_BEARER to a valid token."
echo "Or use credgoo: uv pip install -r https://skale.dev/credgoo && credgoo web-search ..."
