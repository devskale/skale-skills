#!/usr/bin/env python3
"""
Validate AGENTS.md files against best practices.

Usage:
    python validate_agents_md.py path/to/AGENTS.md
"""

import sys
import os
import re
from pathlib import Path
from typing import List, Tuple

class AGENTSValidator:
    """Validator for AGENTS.md files based on Vercel research and best practices."""
    
    def __init__(self, filepath: str):
        self.filepath = Path(filepath)
        self.content = ""
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.info: List[str] = []
        
    def validate(self) -> Tuple[bool, List[str], List[str], List[str]]:
        """Run all validations and return results."""
        if not self.filepath.exists():
            self.errors.append(f"File not found: {self.filepath}")
            return False, self.errors, self.warnings, self.info
        
        self.content = self.filepath.read_text(encoding='utf-8')
        
        # Run all validation checks
        self._check_size()
        self._check_retrieval_instruction()
        self._check_framework_version()
        self._check_structure()
        self._check_compression()
        self._check_common_sections()
        self._check_antipatterns()
        
        # Validation passes if no errors
        return len(self.errors) == 0, self.errors, self.warnings, self.info
    
    def _check_size(self):
        """Check if file size is appropriate."""
        size_bytes = len(self.content.encode('utf-8'))
        size_kb = size_bytes / 1024
        
        if size_kb > 15:
            self.errors.append(f"File too large: {size_kb:.1f}KB (should be <10KB)")
        elif size_kb > 10:
            self.warnings.append(f"File size: {size_kb:.1f}KB (recommend <10KB for optimal performance)")
        else:
            self.info.append(f"✓ File size: {size_kb:.1f}KB (good)")
    
    def _check_retrieval_instruction(self):
        """Check for retrieval-led reasoning instruction."""
        patterns = [
            r"prefer retrieval-led reasoning",
            r"retrieval over.*training",
            r"consult.*documentation.*training",
        ]
        
        found = any(re.search(pattern, self.content, re.IGNORECASE) for pattern in patterns)
        
        if not found:
            self.warnings.append(
                "Missing 'prefer retrieval-led reasoning' instruction. "
                "Add: 'IMPORTANT: Prefer retrieval-led reasoning over pre-training-led reasoning'"
            )
        else:
            self.info.append("✓ Retrieval instruction found")
    
    def _check_framework_version(self):
        """Check if framework versions are specified."""
        # Common framework patterns
        framework_patterns = [
            r"Next\.js\s+\d+",
            r"React\s+\d+",
            r"Vue\s+\d+",
            r"Django\s+\d+",
            r"FastAPI\s+\d+",
            r"Express\s+\d+",
            r"Flask\s+\d+",
            r"Rails\s+\d+",
            r"Angular\s+\d+",
            r"Svelte\s+\d+",
        ]
        
        found_versions = []
        for pattern in framework_patterns:
            matches = re.findall(pattern, self.content, re.IGNORECASE)
            found_versions.extend(matches)
        
        if not found_versions:
            self.warnings.append(
                "No framework versions detected. Include specific versions like 'Next.js 16' or 'React 18'"
            )
        else:
            self.info.append(f"✓ Framework versions found: {', '.join(set(found_versions))}")
    
    def _check_structure(self):
        """Check for expected structural sections."""
        required_sections = [
            (r"#.*project.*overview", "Project Overview"),
            (r"#.*tech.*stack", "Tech Stack"),
        ]
        
        recommended_sections = [
            (r"#.*architecture", "Architecture"),
            (r"#.*conventions", "Key Conventions / Code Style"),
            (r"#.*commands", "Common Commands"),
        ]
        
        for pattern, name in required_sections:
            if not re.search(pattern, self.content, re.IGNORECASE):
                self.warnings.append(f"Missing recommended section: {name}")
        
        for pattern, name in recommended_sections:
            if not re.search(pattern, self.content, re.IGNORECASE):
                self.info.append(f"Consider adding section: {name}")
    
    def _check_compression(self):
        """Check if documentation is appropriately compressed."""
        # Look for pipe-delimited format (good)
        pipe_format = re.search(r'\|root:', self.content)
        
        # Look for verbose documentation (bad)
        long_paragraphs = len(re.findall(r'\n\n.{500,}\n\n', self.content))
        
        if pipe_format:
            self.info.append("✓ Using compressed pipe-delimited documentation index")
        
        if long_paragraphs > 5:
            self.warnings.append(
                f"Found {long_paragraphs} very long paragraphs. "
                "Consider compressing or moving to separate reference files."
            )
    
    def _check_common_sections(self):
        """Check for environment variables and commands."""
        has_env_vars = bool(re.search(r'environment.*variable', self.content, re.IGNORECASE))
        has_commands = bool(re.search(r'(dev:|build:|test:|\`npm run|\`python)', self.content, re.IGNORECASE))
        
        if not has_env_vars:
            self.info.append("Consider documenting required environment variables")
        else:
            self.info.append("✓ Environment variables documented")
        
        if not has_commands:
            self.info.append("Consider documenting common commands (dev, build, test)")
        else:
            self.info.append("✓ Common commands documented")
    
    def _check_antipatterns(self):
        """Check for common anti-patterns."""
        # Check for embedded full documentation
        if len(self.content.split('\n')) > 500:
            self.warnings.append(
                "File has >500 lines. Consider moving detailed docs to reference files and using indexes."
            )
        
        # Check for historical context
        history_indicators = [
            "we started", "initially", "back in", "history", "originally",
            "migrated from", "used to use"
        ]
        for indicator in history_indicators:
            if indicator in self.content.lower():
                self.warnings.append(
                    f"Detected historical context ('{indicator}'). "
                    "Focus on current state rather than history."
                )
                break
        
        # Check for basic explanations
        basic_explanations = [
            "what is typescript", "typescript is a", "what is react",
            "react is a", "what is python"
        ]
        for explanation in basic_explanations:
            if explanation in self.content.lower():
                self.warnings.append(
                    "Avoid explaining basic concepts agents already know. "
                    "Focus on project-specific information."
                )
                break
        
        # Check for excessive examples
        code_block_count = len(re.findall(r'```', self.content))
        if code_block_count > 20:
            self.warnings.append(
                f"Many code examples ({code_block_count // 2} code blocks). "
                "Consider moving examples to reference files."
            )

def main():
    if len(sys.argv) != 2:
        print("Usage: python validate_agents_md.py path/to/AGENTS.md")
        sys.exit(1)
    
    filepath = sys.argv[1]
    validator = AGENTSValidator(filepath)
    
    print(f"Validating: {filepath}\n")
    print("=" * 60)
    
    is_valid, errors, warnings, info = validator.validate()
    
    # Print results
    if errors:
        print("\n❌ ERRORS:")
        for error in errors:
            print(f"  • {error}")
    
    if warnings:
        print("\n⚠️  WARNINGS:")
        for warning in warnings:
            print(f"  • {warning}")
    
    if info:
        print("\n💡 INFO:")
        for item in info:
            print(f"  • {item}")
    
    print("\n" + "=" * 60)
    
    if is_valid:
        print("✅ Validation passed!")
        if warnings:
            print(f"   ({len(warnings)} warnings - consider addressing them)")
        return 0
    else:
        print("❌ Validation failed!")
        print(f"   {len(errors)} error(s), {len(warnings)} warning(s)")
        return 1

if __name__ == "__main__":
    sys.exit(main())
