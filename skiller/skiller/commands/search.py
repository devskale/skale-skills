"""Search command implementation to query the local skill index."""

from __future__ import annotations

import argparse
import os
import json
import re
from typing import Any

from skiller.commands.base import Command

def _add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "query",
        nargs="?",
        default="",
        help="Search query for skill names or descriptions",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results in JSON format",
    )

def _load_index() -> list[dict[str, Any]]:
    """Load skills from the local index file."""
    index_path = os.path.join(os.getcwd(), "skiller_index.json")
    if os.path.exists(index_path):
        try:
            with open(index_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("skills", [])
        except Exception as e:
            print(f"Error loading index: {e}")
            return []
    return []


def _tokenize(text: str) -> list[str]:
    """Tokenize text into words, handling common variations."""
    # Split by whitespace and common delimiters
    words = re.split(r'[\s\-_:.,;()]+', text.lower())
    # Remove empty strings and short words (less than 2 chars)
    return [w for w in words if len(w) >= 2]


def _calculate_relevance(skill: dict, query_tokens: list[str]) -> tuple[int, str]:
    """Calculate relevance score for a skill.
    
    Returns:
        Tuple of (score, highlight_text) where higher score is better.
    """
    name = skill.get("name", "").lower()
    description = skill.get("description", "").lower()
    combined_text = f"{name} {description}"
    
    score = 0
    matches = []
    
    # Calculate matches with weights
    for token in query_tokens:
        # Name matches have highest weight (weight 3)
        if token in name:
            score += 3
            matches.append(('name', token))
        # Description matches have medium weight (weight 2)
        elif token in description:
            score += 2
            matches.append(('description', token))
    
    return score, matches


def _highlight_match(text: str, query: str, max_length: int = 100) -> str:
    """Highlight matching query terms in text."""
    if not query or not text:
        return text[:max_length] + "..." if len(text) > max_length else text
    
    # Find matches and highlight them
    highlighted = text
    for word in query.split():
        if len(word) >= 3:  # Only highlight meaningful words
            pattern = re.compile(f'({re.escape(word.lower())})', re.IGNORECASE)
            highlighted = pattern.sub(r'**\1**', highlighted)
            if highlighted != text:
                highlighted = highlighted
    
    # Truncate at word boundary
    if len(highlighted) > max_length:
        truncated = highlighted[:max_length]
        # Find last space or punctuation to avoid cutting mid-word
        last_space = max(truncated.rfind(' '), truncated.rfind('.'), truncated.rfind(','), truncated.rfind(';'))
        if last_space > max_length - 20:
            highlighted = truncated[:last_space + 1] + "..."
    
    return highlighted


def _run(args: argparse.Namespace, config: dict) -> None:
    """Run the search command."""
    skills = _load_index()
    if not skills:
        print("Index is empty. Run 'skiller crawl' first to populate it.")
        return

    query = args.query.lower().strip()
    
    if not query:
        print("Please provide a search query.")
        return
    
    # Tokenize query into words
    query_tokens = _tokenize(query)
    
    # Calculate relevance for all skills
    scored_results = []
    for skill in skills:
        score, matches = _calculate_relevance(skill, query_tokens)
        if score > 0:
            scored_results.append((skill, score, matches))
    
    # Sort by relevance (higher score first), then by name
    scored_results.sort(key=lambda x: (-x[1], x[0].get("name", "")))
    
    # Extract top results
    max_results = 50  # Limit to 50 most relevant results
    results = [skill for skill, score, matches in scored_results[:max_results]]

    if args.json:
        print(json.dumps(results, indent=2))
        return

    if not results:
        print(f"No skills found matching '{args.query}'.")
        if len(query_tokens) > 1:
            print(f"  Query words: {', '.join(query_tokens)}")
        return

    print(f"Found {len(results)} skills matching '{args.query}':\n")
    if len(query_tokens) > 1:
        print(f"  (Searching for: {', '.join(query_tokens)})\n")
    
    for i, skill in enumerate(results, 1):
        print(f"  [{i}] {skill['name']}")
        
        # Show description with highlighting
        desc = skill.get("description", "(no description)")
        if desc and desc != "(no description)":
            highlighted_desc = _highlight_match(desc, args.query)
            print(f"      {highlighted_desc}")
        
        # Show URL
        url = skill.get("url", "")
        if url:
            print(f"      URL: {url}")
        
        # Show source
        source = skill.get("source", "")
        if source:
            print(f"      Source: {source}")
        
        if i < len(results):
            print()

def _run_interactive(config: dict) -> None:
    """Interactive version of the search command."""
    import questionary
    
    query = questionary.text("Enter search query:").ask()
    if query is None:
        return
        
    class Args:
        pass
    args = Args()
    args.query = query
    args.json = False
    _run(args, config)

command = Command(
    name="search",
    help="Search for skills in the crawled index",
    add_arguments=_add_arguments,
    run=_run,
    run_interactive=_run_interactive,
)
