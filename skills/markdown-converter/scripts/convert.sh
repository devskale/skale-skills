#!/usr/bin/env bash
# Convert files to Markdown using markitdown.

MARKITDOWN="/Users/johannwaldherr/.local/bin/markitdown"

if [[ ! -x "$MARKITDOWN" ]]; then
    echo "Error: markitdown not found at $MARKITDOWN" >&2
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo "Usage: convert.sh <input_file> [output_file]" >&2
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 1
fi

if [[ -n "$OUTPUT_FILE" ]]; then
    "$MARKITDOWN" "$INPUT_FILE" -o "$OUTPUT_FILE"
    echo "Converted: $INPUT_FILE -> $OUTPUT_FILE"
else
    "$MARKITDOWN" "$INPUT_FILE"
fi
