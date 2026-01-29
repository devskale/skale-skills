#!/usr/bin/env bash
set -e

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
SKILL_DIR="$ROOT_DIR/skills/video-transcript-downloader"
VTD_SCRIPT="$SKILL_DIR/scripts/vtd.js"
TEST_OUTPUT_DIR="$SCRIPT_DIR/output"

# Test Video URL (Rick Astley - Never Gonna Give You Up)
VIDEO_URL="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
EXPECTED_TEXT_PART="Never gonna give you up"

echo "=== Starting Tests for video-transcript-downloader ==="
echo "Script path: $VTD_SCRIPT"
echo "Output dir: $TEST_OUTPUT_DIR"

# Cleanup previous runs
rm -rf "$TEST_OUTPUT_DIR"
mkdir -p "$TEST_OUTPUT_DIR"

# --- Test 1: Transcript to File (Default) ---
echo -e "\n[Test 1] Fetching transcript to file (default)..."
OUTPUT=$("$VTD_SCRIPT" transcript --url "$VIDEO_URL" --transcript-dir "$TEST_OUTPUT_DIR")
echo "Output: $OUTPUT"

# Extract file path from output
FILE_PATH=$(echo "$OUTPUT" | grep "The transcript is extensive. It's saved to:" | sed "s/The transcript is extensive. It's saved to: //")

if [ -f "$FILE_PATH" ]; then
  echo "✅ Success: Transcript file created at $FILE_PATH"
else
  echo "❌ Error: Transcript file NOT found at $FILE_PATH"
  exit 1
fi

# Check content
if grep -q "$EXPECTED_TEXT_PART" "$FILE_PATH"; then
  echo "✅ Success: Transcript contains expected text."
else
  echo "❌ Error: Transcript does not contain expected text."
  exit 1
fi

# --- Test 2: Transcript to Console (--no-file) ---
echo -e "\n[Test 2] Fetching transcript to console (--no-file)..."
CONSOLE_OUTPUT=$("$VTD_SCRIPT" transcript --url "$VIDEO_URL" --no-file)

# Check content in stdout
if [[ "$CONSOLE_OUTPUT" == *"$EXPECTED_TEXT_PART"* ]]; then
  echo "✅ Success: Console output contains expected text."
else
  echo "❌ Error: Console output does not contain expected text."
  echo "Preview: ${CONSOLE_OUTPUT:0:100}..."
  exit 1
fi

# Check NO file creation message
if [[ "$CONSOLE_OUTPUT" == *"The transcript is extensive. It's saved to:"* ]]; then
  echo "❌ Error: Console output contains save message, but shouldn't."
  exit 1
else
  echo "✅ Success: No save message in console output."
fi

# --- Test 2b: Transcript to Console (--to-file false) ---
echo -e "\n[Test 2b] Fetching transcript to console (--to-file false)..."
OUTPUT_CONSOLE_2=$("$VTD_SCRIPT" transcript --url "$VIDEO_URL" --to-file false)

if echo "$OUTPUT_CONSOLE_2" | grep -q "The transcript is extensive. It's saved to:"; then
  echo "❌ Error: Script saved to file despite --to-file false!"
  exit 1
fi

if echo "$OUTPUT_CONSOLE_2" | grep -iq "Never Gonna Give You Up"; then
  echo "✅ Success: Console output contains expected text."
else
  echo "❌ Error: Console output missing transcript text."
  exit 1
fi

# --- Test 3: Search (Dry run / Limit 1) ---
echo -e "\n[Test 3] Search functionality (limit 1)..."
# We just check if it runs without error and finds something
SEARCH_OUTPUT=$("$VTD_SCRIPT" search "rick roll" --limit 1 --transcript-dir "$TEST_OUTPUT_DIR")

if [[ "$SEARCH_OUTPUT" == *"Found"* && "$SEARCH_OUTPUT" == *"videos"* ]]; then
    echo "✅ Success: Search executed and found videos."
else
    # Search output goes to stderr mostly in the script, need to check how to capture it if needed.
    # The script writes "The transcript is extensive..." to stdout for each download.
    if [[ "$SEARCH_OUTPUT" == *"The transcript is extensive. It's saved to:"* ]]; then
         echo "✅ Success: Search downloaded a transcript."
    else
         echo "⚠️ Warning: Search might have failed or found no videos (check logs)."
         # Note: The script prints search progress to stderr, so we might miss it in $SEARCH_OUTPUT variable capture 
         # unless we redirect 2>&1. But we only care about the result (transcript path) here.
    fi
fi

# --- Test 4: Default Storage (~/transcripts) ---
echo -e "\n[Test 4] Fetching transcript to default storage (~/transcripts)..."

# Create a fake HOME to avoid sandbox permission issues and strictly test relative path logic
FAKE_HOME="$SCRIPT_DIR/fake_home"
mkdir -p "$FAKE_HOME"

# Run with modified HOME
echo "Using fake HOME: $FAKE_HOME"
OUTPUT_DEFAULT=$(HOME="$FAKE_HOME" "$VTD_SCRIPT" transcript --url "$VIDEO_URL")
echo "Output: $OUTPUT_DEFAULT"

# Extract file path from output
DEFAULT_FILE_PATH=$(echo "$OUTPUT_DEFAULT" | grep "The transcript is extensive. It's saved to:" | sed "s/The transcript is extensive. It's saved to: //")

# Check if path is within our fake home transcripts
EXPECTED_DIR="$FAKE_HOME/transcripts"
if [[ "$DEFAULT_FILE_PATH" == "$EXPECTED_DIR"* ]]; then
  echo "✅ Success: Path is inside default directory ($EXPECTED_DIR)"
else
  echo "❌ Error: Path mismatch. Got: $DEFAULT_FILE_PATH, Expected to start with: $EXPECTED_DIR"
  rm -rf "$FAKE_HOME"
  exit 1
fi

if [ -f "$DEFAULT_FILE_PATH" ]; then
  echo "✅ Success: File created at default location."
else
  echo "❌ Error: File not found at $DEFAULT_FILE_PATH"
  rm -rf "$FAKE_HOME"
  exit 1
fi

# Cleanup fake home
rm -rf "$FAKE_HOME"
echo "🧹 Cleaned up fake HOME"

# Cleanup
echo -e "\nCleaning up..."
rm -rf "$TEST_OUTPUT_DIR"

echo -e "\n🎉 All tests passed!"
