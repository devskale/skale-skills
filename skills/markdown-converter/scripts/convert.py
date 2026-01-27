#!/usr/bin/env python3
"""Convert files to Markdown using markitdown."""

import sys
import os
from pathlib import Path

try:
    from markitdown import MarkItDown
except ImportError:
    print("markitdown not installed. Install with: pip install markitdown", file=sys.stderr)
    sys.exit(1)


def convert_file(input_path: str, output_path: str = None) -> str:
    """Convert a file to Markdown."""
    input_file = Path(input_path)
    if not input_file.exists():
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    md = MarkItDown()
    result = md.convert(str(input_file))

    if output_path:
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)
        output_file.write_text(result.text_content)
        return str(output_file)
    else:
        return result.text_content


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: convert_markdown.py <input_file> [output_file]", file=sys.stderr)
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None

    result = convert_file(input_file, output_file)
    if output_file:
        print(f"Converted: {input_file} -> {output_file}")
    else:
        print(result)
