"""Discovery command implementation."""

from __future__ import annotations

import argparse
import os

from skiller.commands.base import Command
from skiller.commands.install import install_candidates
from skiller.core import discover_skills_in_tree, list_skills_simple, list_discovered_skills_in_tree
from skiller.ui import select_multiple, select_option


def _add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "dir",
        nargs="?",
        default=os.getcwd(),
        help="Directory to scan for skills (default: current directory)",
    )


def _run(args: argparse.Namespace, config: dict) -> None:
    base_dir = os.path.expanduser(args.dir)
    
    discovery_dirs = config.get("discovery_dirs", [])
    if discovery_dirs:
        print(f"Scanning discovery_dirs from config:")
        for d in discovery_dirs:
            print(f"\n  {d}:")
            list_discovered_skills_in_tree(d, max_depth=3)
    
    subdirs = config.get("custom_subdirs") or [".opencode/skills", ".claude/skills"]
    if discovery_dirs:
        print(f"\nScanning for agent directories in {base_dir}:")
    list_skills_simple(base_dir, subdirs)


def _run_interactive(config: dict) -> None:
    base_dir = os.getcwd()
    discovery_choices = ["discovery_dirs", "custom_dirs", "./"]
    discovery_scope = select_option(
        "Discover skills in:", discovery_choices, default="discovery_dirs"
    )
    if not discovery_scope:
        return
    
    if discovery_scope == "discovery_dirs":
        discovery_dirs = config.get("discovery_dirs", [])
        if not discovery_dirs:
            print("No discovery_dirs configured in skiller_config.json")
            return
        
        all_discovered = []
        for d in discovery_dirs:
            discovered = discover_skills_in_tree(d, max_depth=3)
            all_discovered.extend(discovered)
        
        if not all_discovered:
            print("No skills discovered in discovery_dirs.")
            return
        
        choices = []
        for item in all_discovered:
            desc = item["description"]
            desc_short = desc if len(desc) <= 80 else f"{desc[:77]}..."
            choices.append(f"{item['name']} [{item['rel_path']}] - {desc_short}")
        selected = select_multiple(
            "Select skills to install:", choices, default=[choices[0]] if choices else None
        )
        if not selected:
            return
        selected_candidates = [
            all_discovered[choices.index(choice)] for choice in selected if choice in choices
        ]
        if not selected_candidates:
            return
        install_candidates(selected_candidates, config)
        return
    
    if discovery_scope == "./":
        discovered = discover_skills_in_tree(base_dir, max_depth=3)
        if not discovered:
            print("No skills discovered in the specified directory.")
            return
        choices = []
        for item in discovered:
            desc = item["description"]
            desc_short = desc if len(desc) <= 80 else f"{desc[:77]}..."
            choices.append(f"{item['name']} [{item['rel_path']}] - {desc_short}")
        selected = select_multiple(
            "Select skills to install:", choices, default=[choices[0]]
        )
        if not selected:
            return
        selected_candidates = [
            discovered[choices.index(choice)] for choice in selected if choice in choices
        ]
        if not selected_candidates:
            return
        install_candidates(selected_candidates, config)
        return
    
    # custom_dirs
    subdirs = config.get("custom_subdirs") or [".opencode/skills", ".claude/skills"]
    list_skills_simple(base_dir, subdirs)


command = Command(
    name="discovery",
    help="Discover skills in a directory",
    add_arguments=_add_arguments,
    run=_run,
    run_interactive=_run_interactive,
)
