#!/usr/bin/env python3
"""
Create compressed documentation index for AGENTS.md.

This script scans a documentation directory and creates a compressed
pipe-delimited index suitable for inclusion in AGENTS.md files.

Usage:
    python create_docs_index.py /path/to/docs --output index.txt
    python create_docs_index.py /path/to/docs --framework "Next.js 16"
"""

import sys
import os
import argparse
from pathlib import Path
from typing import Dict, List, Set
from collections import defaultdict

class DocsIndexer:
    """Create compressed documentation indexes."""
    
    def __init__(self, docs_path: str, framework_name: str = "Framework"):
        self.docs_path = Path(docs_path)
        self.framework_name = framework_name
        self.file_extensions = {'.md', '.mdx', '.txt'}
        self.index_data: Dict[str, List[str]] = defaultdict(list)
        
    def scan(self) -> Dict[str, List[str]]:
        """Scan documentation directory and build index."""
        if not self.docs_path.exists():
            raise ValueError(f"Documentation path does not exist: {self.docs_path}")
        
        for file_path in self.docs_path.rglob('*'):
            if file_path.is_file() and file_path.suffix in self.file_extensions:
                # Get relative path from docs root
                rel_path = file_path.relative_to(self.docs_path)
                
                # Get directory path
                if rel_path.parent == Path('.'):
                    dir_key = "root"
                else:
                    dir_key = str(rel_path.parent)
                
                # Add filename to this directory's list
                self.index_data[dir_key].append(file_path.name)
        
        return self.index_data
    
    def generate_compressed_index(self) -> str:
        """Generate compressed pipe-delimited index format."""
        lines = []
        
        # Header
        lines.append(f"[{self.framework_name} Docs]|root:{self.docs_path}")
        lines.append("|IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning")
        
        # Sort directories for consistent output
        sorted_dirs = sorted(self.index_data.keys())
        
        for directory in sorted_dirs:
            files = sorted(self.index_data[directory])
            files_str = "{" + ",".join(files) + "}"
            lines.append(f"|{directory}:{files_str}")
        
        return "\n".join(lines)
    
    def generate_expanded_index(self) -> str:
        """Generate more readable expanded index format."""
        lines = []
        
        # Header
        lines.append(f"## {self.framework_name} Documentation")
        lines.append("")
        lines.append(f"**Root:** `{self.docs_path}`")
        lines.append("")
        lines.append("**IMPORTANT:** Prefer retrieval-led reasoning over pre-training-led reasoning.")
        lines.append("")
        
        # Sort directories for consistent output
        sorted_dirs = sorted(self.index_data.keys())
        
        for directory in sorted_dirs:
            # Format directory name as section header
            section_name = directory.replace('-', ' ').replace('_', ' ').title()
            if directory == "root":
                section_name = "Root Documentation"
            
            lines.append(f"### {section_name}")
            
            files = sorted(self.index_data[directory])
            for filename in files:
                if directory == "root":
                    file_path = filename
                else:
                    file_path = f"{directory}/{filename}"
                
                # Try to make a nice description from filename
                description = filename.replace('-', ' ').replace('_', ' ').replace('.md', '').replace('.mdx', '').title()
                lines.append(f"- `{file_path}` - {description}")
            
            lines.append("")
        
        return "\n".join(lines)
    
    def calculate_size(self, content: str) -> float:
        """Calculate size in KB."""
        return len(content.encode('utf-8')) / 1024
    
    def generate_stats(self) -> str:
        """Generate statistics about the index."""
        total_files = sum(len(files) for files in self.index_data.values())
        total_dirs = len(self.index_data)
        
        compressed = self.generate_compressed_index()
        expanded = self.generate_expanded_index()
        
        compressed_size = self.calculate_size(compressed)
        expanded_size = self.calculate_size(expanded)
        compression_ratio = (1 - compressed_size / expanded_size) * 100
        
        stats = [
            "Index Statistics:",
            f"  Total files: {total_files}",
            f"  Total directories: {total_dirs}",
            f"  Compressed size: {compressed_size:.2f} KB",
            f"  Expanded size: {expanded_size:.2f} KB",
            f"  Compression: {compression_ratio:.1f}%",
        ]
        
        return "\n".join(stats)

def main():
    parser = argparse.ArgumentParser(
        description="Create compressed documentation index for AGENTS.md"
    )
    parser.add_argument(
        "docs_path",
        help="Path to documentation directory"
    )
    parser.add_argument(
        "--framework",
        default="Framework",
        help="Framework name (e.g., 'Next.js 16', 'Django 5')"
    )
    parser.add_argument(
        "--output",
        help="Output file path (default: print to stdout)"
    )
    parser.add_argument(
        "--format",
        choices=["compressed", "expanded"],
        default="compressed",
        help="Output format (default: compressed)"
    )
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Show statistics"
    )
    
    args = parser.parse_args()
    
    # Create indexer and scan
    indexer = DocsIndexer(args.docs_path, args.framework)
    
    try:
        indexer.scan()
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    
    # Generate output
    if args.format == "compressed":
        output = indexer.generate_compressed_index()
    else:
        output = indexer.generate_expanded_index()
    
    # Write or print output
    if args.output:
        Path(args.output).write_text(output, encoding='utf-8')
        print(f"✓ Index written to: {args.output}")
    else:
        print(output)
    
    # Show stats if requested
    if args.stats:
        print("\n" + "=" * 60)
        print(indexer.generate_stats())
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
