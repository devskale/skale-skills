#!/usr/bin/env python3
"""
Compression utilities for AGENTS.md files.

Provides various compression techniques to reduce file size while
maintaining readability and utility for AI agents.

Usage:
    python compress_docs.py input.md --output compressed.md
    python compress_docs.py input.md --analyze  # Show compression opportunities
"""

import sys
import re
import argparse
from pathlib import Path
from typing import List, Tuple

class AGENTSCompressor:
    """Compress AGENTS.md files using various techniques."""
    
    def __init__(self, content: str):
        self.original = content
        self.compressed = content
        self.techniques_applied: List[str] = []
    
    def analyze(self) -> str:
        """Analyze content and suggest compression opportunities."""
        lines = self.original.split('\n')
        
        analysis = []
        analysis.append("Compression Analysis")
        analysis.append("=" * 60)
        analysis.append("")
        
        # Size analysis
        size_kb = len(self.original.encode('utf-8')) / 1024
        analysis.append(f"Current size: {size_kb:.2f} KB")
        
        if size_kb > 10:
            analysis.append("  ⚠️ Over recommended 10KB limit")
        else:
            analysis.append("  ✓ Within recommended size")
        
        analysis.append("")
        
        # Identify long paragraphs
        long_paragraphs = []
        current_para = []
        for line in lines:
            if line.strip():
                current_para.append(line)
            else:
                if len(current_para) > 5:
                    para_text = ' '.join(current_para)
                    if len(para_text) > 500:
                        long_paragraphs.append(len(para_text))
                current_para = []
        
        if long_paragraphs:
            analysis.append(f"Long paragraphs: {len(long_paragraphs)} paragraphs over 500 chars")
            analysis.append(f"  Longest: {max(long_paragraphs)} characters")
            analysis.append("  💡 Consider breaking into bullet points or moving to reference files")
            analysis.append("")
        
        # Check for code blocks
        code_blocks = len(re.findall(r'```', self.original)) // 2
        if code_blocks > 10:
            analysis.append(f"Code blocks: {code_blocks} blocks")
            analysis.append("  💡 Consider moving examples to reference files")
            analysis.append("")
        
        # Check for repetitive phrases
        common_phrases = self._find_repetitive_phrases()
        if common_phrases:
            analysis.append("Repetitive phrases (can be abbreviated):")
            for phrase, count in common_phrases[:5]:
                analysis.append(f"  • '{phrase}' appears {count} times")
            analysis.append("")
        
        # Check for verbose lists
        verbose_lists = self._find_verbose_lists()
        if verbose_lists:
            analysis.append(f"Verbose lists: {len(verbose_lists)} lists with long items")
            analysis.append("  💡 Consider using more concise format")
            analysis.append("")
        
        return '\n'.join(analysis)
    
    def compress_all(self) -> str:
        """Apply all compression techniques."""
        self.remove_redundant_whitespace()
        self.compress_lists()
        self.abbreviate_common_phrases()
        self.condense_paragraphs()
        return self.compressed
    
    def remove_redundant_whitespace(self):
        """Remove excessive blank lines and trailing whitespace."""
        # Remove trailing whitespace
        lines = [line.rstrip() for line in self.compressed.split('\n')]
        
        # Replace 3+ blank lines with 2
        compressed_lines = []
        blank_count = 0
        for line in lines:
            if not line.strip():
                blank_count += 1
                if blank_count <= 2:
                    compressed_lines.append(line)
            else:
                blank_count = 0
                compressed_lines.append(line)
        
        self.compressed = '\n'.join(compressed_lines)
        self.techniques_applied.append("removed redundant whitespace")
    
    def compress_lists(self):
        """Compress verbose list items."""
        # Pattern: "- The project uses X for Y"
        # Replace with: "- X (Y)"
        patterns = [
            (r'- The project uses (\w+) for (.+)', r'- \1 (\2)'),
            (r'- We use (\w+) for (.+)', r'- \1 (\2)'),
            (r'- This project uses (\w+) for (.+)', r'- \1 (\2)'),
        ]
        
        for pattern, replacement in patterns:
            if re.search(pattern, self.compressed):
                self.compressed = re.sub(pattern, replacement, self.compressed)
                self.techniques_applied.append("compressed list items")
                break
    
    def abbreviate_common_phrases(self):
        """Replace verbose phrases with abbreviations."""
        replacements = [
            (r'For more information about', 'See'),
            (r'For more details on', 'See'),
            (r'Please refer to', 'See'),
            (r'You can find', 'See'),
            (r'documentation/', 'docs/'),
            (r'Documentation/', 'Docs/'),
        ]
        
        for pattern, replacement in replacements:
            if pattern in self.compressed:
                self.compressed = self.compressed.replace(pattern, replacement)
                if "abbreviated common phrases" not in self.techniques_applied:
                    self.techniques_applied.append("abbreviated common phrases")
    
    def condense_paragraphs(self):
        """Condense verbose explanatory paragraphs."""
        # This is more conservative - just removes some common verbosity
        verbose_phrases = [
            r'It is important to note that ',
            r'Please note that ',
            r'It should be noted that ',
            r'Keep in mind that ',
            r'Remember that ',
        ]
        
        for phrase in verbose_phrases:
            if re.search(phrase, self.compressed, re.IGNORECASE):
                self.compressed = re.sub(phrase, '', self.compressed, flags=re.IGNORECASE)
                if "condensed paragraphs" not in self.techniques_applied:
                    self.techniques_applied.append("condensed paragraphs")
    
    def _find_repetitive_phrases(self) -> List[Tuple[str, int]]:
        """Find phrases that appear multiple times."""
        # Look for 3-5 word phrases
        words = self.original.split()
        phrase_counts = {}
        
        for length in [3, 4, 5]:
            for i in range(len(words) - length):
                phrase = ' '.join(words[i:i+length])
                # Skip code and very short phrases
                if '`' not in phrase and len(phrase) > 20:
                    phrase_counts[phrase] = phrase_counts.get(phrase, 0) + 1
        
        # Return phrases that appear 3+ times
        repetitive = [(p, c) for p, c in phrase_counts.items() if c >= 3]
        return sorted(repetitive, key=lambda x: x[1], reverse=True)
    
    def _find_verbose_lists(self) -> List[str]:
        """Find list items that are particularly verbose."""
        lines = self.original.split('\n')
        verbose = []
        
        for line in lines:
            if line.strip().startswith(('-', '*', '+')):
                if len(line) > 150:  # Long list item
                    verbose.append(line.strip())
        
        return verbose
    
    def get_compression_stats(self) -> str:
        """Get statistics about compression."""
        original_size = len(self.original.encode('utf-8')) / 1024
        compressed_size = len(self.compressed.encode('utf-8')) / 1024
        reduction = original_size - compressed_size
        reduction_pct = (reduction / original_size) * 100 if original_size > 0 else 0
        
        stats = []
        stats.append("Compression Results")
        stats.append("=" * 60)
        stats.append(f"Original size:   {original_size:.2f} KB")
        stats.append(f"Compressed size: {compressed_size:.2f} KB")
        stats.append(f"Reduction:       {reduction:.2f} KB ({reduction_pct:.1f}%)")
        stats.append("")
        stats.append("Techniques applied:")
        for technique in self.techniques_applied:
            stats.append(f"  • {technique}")
        
        return '\n'.join(stats)

def main():
    parser = argparse.ArgumentParser(
        description="Compress AGENTS.md files"
    )
    parser.add_argument(
        "input",
        help="Input AGENTS.md file"
    )
    parser.add_argument(
        "--output",
        help="Output file path (default: overwrite input)"
    )
    parser.add_argument(
        "--analyze",
        action="store_true",
        help="Analyze compression opportunities without modifying"
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Show compression statistics"
    )
    
    args = parser.parse_args()
    
    # Read input
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: File not found: {input_path}", file=sys.stderr)
        return 1
    
    content = input_path.read_text(encoding='utf-8')
    compressor = AGENTSCompressor(content)
    
    # Analyze mode
    if args.analyze:
        print(compressor.analyze())
        return 0
    
    # Compress
    compressed = compressor.compress_all()
    
    # Write output
    output_path = Path(args.output) if args.output else input_path
    output_path.write_text(compressed, encoding='utf-8')
    
    print(f"✓ Compressed file written to: {output_path}")
    
    if args.stats:
        print("\n" + compressor.get_compression_stats())
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
