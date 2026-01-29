"""Search command implementation to query the local skill index."""

from __future__ import annotations

import argparse
import os
import json
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

def _run(args: argparse.Namespace, config: dict) -> None:
    """Run the search command."""
    skills = _load_index()
    if not skills:
        print("Index is empty. Run 'skiller crawl' first to populate it.")
        return

    query = args.query.lower()
    results = []

    for skill in skills:
        # Search in name and description
        name = skill.get("name", "").lower()
        description = skill.get("description", "").lower()
        if query in name or query in description:
            results.append(skill)

    if args.json:
        print(json.dumps(results, indent=2))
        return

    if not results:
        print(f"No skills found matching '{args.query}'.")
        return

    print(f"Found {len(results)} skills matching '{args.query}':\n")
    for skill in results:
        print(f"  - {skill['name']}")
        desc = skill.get("description", "")
        if desc:
            print(f"    Description: {desc[:80]}{'...' if len(desc) > 80 else ''}")
        print(f"    URL: {skill['url']}")
        print(f"    Source: {skill['source']}")
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
