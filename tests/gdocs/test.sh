#!/usr/bin/env bash
set -e

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
TEST_OUTPUT_DIR="$SCRIPT_DIR/output"

# Document ID for BOCtest (editable copy in GOGtest folder)
DOC_ID="1TkIzmsXO9E6A0jLY165TB6-XK9-jMpowbTKZv8S7EHg"
ACCOUNT="hans@vervewatermobility.com"

# Test markers with timestamps
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SIMPLE_MARKER="[GDOCS_TEST_SIMPLE_${TIMESTAMP}]"
SOPHISTICATED_MARKER="[GDOCS_TEST_SOPHISTICATED_${TIMESTAMP}]"

echo "=== Starting Tests for gdocs skill ==="
echo "GOG CLI: gog"
echo "Document ID: $DOC_ID"
echo "Account: $ACCOUNT"
echo "Output dir: $TEST_OUTPUT_DIR"

# Cleanup previous runs
rm -rf "$TEST_OUTPUT_DIR"
mkdir -p "$TEST_OUTPUT_DIR"

# Helper function to run gog with account
gog() {
    command gog --account "$ACCOUNT" "$@"
}

# --- Test 1: Read Document (docs info & cat) ---
echo -e "\n[Test 1] Reading document..."
INFO_OUTPUT=$(gog docs info "$DOC_ID" --json)
echo "Document info retrieved"

if echo "$INFO_OUTPUT" | grep -q '"documentId"'; then
    echo "✅ Success: docs info returned valid JSON"
else
    echo "❌ Error: docs info missing documentId"
    echo "$INFO_OUTPUT"
    exit 1
fi

CONTENT=$(gog docs cat "$DOC_ID" --max-bytes 5000)
echo "Document content preview: ${CONTENT:0:100}..."

if [ -n "$CONTENT" ]; then
    echo "✅ Success: docs cat returned content"
else
    echo "❌ Error: docs cat returned empty content"
    exit 1
fi

# --- Test 2: Write Document (docs write) ---
echo -e "\n[Test 2] Writing document from markdown..."

# Create a test markdown file
TEST_MD="$TEST_OUTPUT_DIR/test_content.md"
cat > "$TEST_MD" << EOF
# GDocs Skill Test Document

This is a test document created by the gdocs skill test suite.

## Test Section

- Test timestamp: $TIMESTAMP
- Simple marker: $SIMPLE_MARKER

### Features Tested
1. Read document (docs info, docs cat)
2. Write document from markdown
3. Find-replace
4. Export to different formats

## Conclusion

All tests will pass successfully!
EOF

echo "Created test markdown file: $TEST_MD"

# Write new content (this replaces entire document)
WRITE_RESULT=$(gog docs write "$DOC_ID" --replace --markdown --file "$TEST_MD")
echo "Write result: $WRITE_RESULT"

# Validate the write
NEW_CONTENT=$(gog docs cat "$DOC_ID")
if echo "$NEW_CONTENT" | grep -q "GDocs Skill Test Document"; then
    echo "✅ Success: New content written to document"
else
    echo "❌ Error: New content NOT found after write"
    echo "Content: $NEW_CONTENT"
    exit 1
fi

# --- Test 3: Simple Edit (find-replace single occurrence) ---
echo -e "\n[Test 3] Simple edit: find-replace..."

REPLACE_RESULT=$(gog docs find-replace "$DOC_ID" "$SIMPLE_MARKER" "$SOPHISTICATED_MARKER")
echo "Replace result: $REPLACE_RESULT"

if echo "$REPLACE_RESULT" | grep -q "replacements.*[1-9]"; then
    echo "✅ Success: find-replace made at least one replacement"
else
    echo "❌ Error: find-replace made no replacements"
    exit 1
fi

# Validate the replacement
VALIDATE_CONTENT=$(gog docs cat "$DOC_ID" --max-bytes 5000)
if echo "$VALIDATE_CONTENT" | grep -q "SOPHISTICATED"; then
    echo "✅ Success: Sophisticated marker found in document after replace"
else
    echo "❌ Error: Sophisticated marker NOT found after replace"
    echo "Content preview: ${VALIDATE_CONTENT:0:500}..."
    exit 1
fi

# Verify simple marker is gone
if echo "$VALIDATE_CONTENT" | grep -q "GDOCS_TEST_SIMPLE"; then
    echo "❌ Error: Simple marker still present (should have been replaced)"
    exit 1
else
    echo "✅ Success: Simple marker was replaced (no longer present)"
fi

# --- Test 4: Export Document ---
echo -e "\n[Test 4] Export document..."

# Export to TXT
TXT_OUT="$TEST_OUTPUT_DIR/exported.txt"
gog docs export "$DOC_ID" --format txt --out "$TXT_OUT"

if [ -f "$TXT_OUT" ]; then
    echo "✅ Success: Exported to TXT"
    if grep -q "GDocs Skill Test Document" "$TXT_OUT"; then
        echo "✅ Success: Exported content matches written content"
    else
        echo "❌ Error: Exported content doesn't match"
        cat "$TXT_OUT"
        exit 1
    fi
else
    echo "❌ Error: Export file not created"
    exit 1
fi

# Export to DOCX
DOCX_OUT="$TEST_OUTPUT_DIR/exported.docx"
gog docs export "$DOC_ID" --format docx --out "$DOCX_OUT"

if [ -f "$DOCX_OUT" ]; then
    echo "✅ Success: Exported to DOCX"
    # Check file size is reasonable (should be > 1KB)
    DOCX_SIZE=$(stat -c%s "$DOCX_OUT" 2>/dev/null || stat -f%z "$DOCX_OUT" 2>/dev/null || wc -c < "$DOCX_OUT")
    if [ "$DOCX_SIZE" -gt 1000 ]; then
        echo "✅ Success: DOCX file size is reasonable ($DOCX_SIZE bytes)"
    else
        echo "❌ Error: DOCX file too small ($DOCX_SIZE bytes)"
        exit 1
    fi
else
    echo "❌ Error: DOCX export file not created"
    exit 1
fi

# Export to PDF
PDF_OUT="$TEST_OUTPUT_DIR/exported.pdf"
gog docs export "$DOC_ID" --format pdf --out "$PDF_OUT"

if [ -f "$PDF_OUT" ]; then
    echo "✅ Success: Exported to PDF"
else
    echo "❌ Error: PDF export file not created"
    exit 1
fi

# --- Test 5: Multiple find-replace operations ---
echo -e "\n[Test 5] Multiple find-replace operations..."

# First write a known state with multiple markers
MULTI_TEST_MD="$TEST_OUTPUT_DIR/multi_test.md"
cat > "$MULTI_TEST_MD" << EOF
Test Document for Multiple Replacements

[MARKER_A]
[MARKER_B]
[MARKER_C]

End of test.
EOF

gog docs write "$DOC_ID" --replace --markdown --file "$MULTI_TEST_MD"

# Perform multiple replacements
echo "Performing replacement A..."
gog docs find-replace "$DOC_ID" "[MARKER_A]" "[REPLACED_A_${TIMESTAMP}]"
echo "Performing replacement B..."
gog docs find-replace "$DOC_ID" "[MARKER_B]" "[REPLACED_B_${TIMESTAMP}]"
echo "Performing replacement C..."
gog docs find-replace "$DOC_ID" "[MARKER_C]" "[REPLACED_C_${TIMESTAMP}]"

# Validate all replacements
MULTI_CONTENT=$(gog docs cat "$DOC_ID")
REPLACEMENTS_FOUND=0

if echo "$MULTI_CONTENT" | grep -q "REPLACED_A"; then
    echo "✅ Replacement A found"
    ((REPLACEMENTS_FOUND++)) || true
fi

if echo "$MULTI_CONTENT" | grep -q "REPLACED_B"; then
    echo "✅ Replacement B found"
    ((REPLACEMENTS_FOUND++)) || true
fi

if echo "$MULTI_CONTENT" | grep -q "REPLACED_C"; then
    echo "✅ Replacement C found"
    ((REPLACEMENTS_FOUND++)) || true
fi

if [ "$REPLACEMENTS_FOUND" -eq 3 ]; then
    echo "✅ Success: All 3 replacements found"
else
    echo "❌ Error: Only $REPLACEMENTS_FOUND/3 replacements found"
    exit 1
fi

# Verify original markers are gone
if echo "$MULTI_CONTENT" | grep -q "\[MARKER_A\]"; then
    echo "❌ Error: MARKER_A still present"
    exit 1
fi
echo "✅ Success: All original markers replaced"

# --- Test 6: Document Copy ---
echo -e "\n[Test 6] Copy document..."

COPY_RESULT=$(gog docs copy "$DOC_ID" "GDocs Test Copy ${TIMESTAMP}" --json)
echo "Copy result: $COPY_RESULT"

if echo "$COPY_RESULT" | grep -q '"id"'; then
    COPY_ID=$(echo "$COPY_RESULT" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    echo "✅ Success: Document copied (new ID: $COPY_ID)"

    # Verify copy has content
    COPY_CONTENT=$(gog docs cat "$COPY_ID" --max-bytes 500)
    if echo "$COPY_CONTENT" | grep -q "REPLACED"; then
        echo "✅ Success: Copy has expected content"
    else
        echo "⚠️ Warning: Copy content differs from expected"
    fi

    # Clean up - delete the copy
    gog drive delete "$COPY_ID" --force
    echo "✅ Test copy deleted"
else
    echo "❌ Error: Copy did not return document ID"
    exit 1
fi

# --- Final: Leave document in clean state ---
echo -e "\n[Cleanup] Writing final test document..."

FINAL_MD="$TEST_OUTPUT_DIR/final.md"
cat > "$FINAL_MD" << EOF
# GDocs Skill Test - Complete

Last test run: $TIMESTAMP

All tests passed successfully!
EOF

gog docs write "$DOC_ID" --replace --markdown --file "$FINAL_MD"

# Cleanup test output
rm -rf "$TEST_OUTPUT_DIR"

echo -e "\n🎉 All gdocs skill tests passed!"
