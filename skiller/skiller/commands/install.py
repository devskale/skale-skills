"""Install command implementation."""

from __future__ import annotations

import argparse
import os
from typing import List, Tuple, Optional

from skiller.commands.base import Command
from skiller.core import _gather_skill_candidates, discover_skills_in_tree, prompt_agents_and_paths
from skiller.ui import select_multiple, select_option


def _add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "skill",
        nargs="*",
        help="Name(s) of skill(s) to install (optional, will prompt if not provided)",
    )
    parser.add_argument(
        "--agent",
        help="Agent to install for (optional, will prompt if not provided)",
    )
    parser.add_argument(
        "--path-type",
        choices=["user", "project"],
        help="Path type to install to (optional, will prompt if not provided)",
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Test mode - show what would be installed without actually installing",
    )


def _copy_skill_tree_test(source: str, destination_root: str) -> Tuple[str, Optional[str]]:
    """Test version of copy_skill_tree that doesn't actually copy."""
    destination_root_exp = os.path.expanduser(destination_root)
    destination_path = os.path.join(destination_root_exp, os.path.basename(source))
    
    if os.path.abspath(destination_path) == os.path.abspath(source):
        return "same", destination_path
    if os.path.exists(destination_path):
        return "exists", destination_path
    return "would_install", destination_path


def install_candidates(
    candidates: List[dict],
    config: dict,
    test_mode: bool = False,
    selected_agents: Optional[List[str]] = None,
    selected_paths: Optional[List[str]] = None,
) -> bool:
    """Install candidates to selected agents and paths.
    
    Returns:
        True if any installation was successful (or would be in test mode)
    """
    # Get agents/paths if not provided
    if selected_agents is None or selected_paths is None:
        selection = prompt_agents_and_paths(config, selected_agents, selected_paths)
        if not selection:
            return False
        selected_agents, selected_paths = selection

    installed_any = False
    had_targets = False
    agent_dirs = config.get("agent_dirs", {}) or {}
    
    for candidate in candidates:
        for agent in selected_agents:
            ad = agent_dirs.get(agent, {}) or {}
            for path_type in selected_paths:
                targets = ad.get(path_type, [])
                if not targets:
                    print(f"No configured {path_type} paths for agent '{agent}'.")
                    continue
                had_targets = True
                for target in targets:
                    if test_mode:
                        status, result_path = _copy_skill_tree_test(candidate["path"], target)
                        prefix = "Would install" if status == "would_install" else "Already installed"
                        print(
                            f"  {prefix} {candidate['name']} for agent '{agent}' ({path_type}) -> {result_path}"
                        )
                        if status in ("would_install", "same"):
                            installed_any = True
                    else:
                        # Use the core copy_skill_tree function
                        from skiller.core import copy_skill_tree
                        status, result_path = copy_skill_tree(candidate["path"], target)
                        if status == "installed":
                            installed_any = True
                            print(
                                f"Installed {candidate['name']} for agent '{agent}' ({path_type}) -> {result_path}"
                            )
                        elif status in ("exists", "same"):
                            print(
                                f"Already installed {candidate['name']} for agent '{agent}' ({path_type}) -> {result_path}"
                            )
    
    if not had_targets:
        print("No install targets were available for the selected agents.")
    elif not installed_any:
        print("No installations were performed (targets already existed or failed).")
    
    return installed_any


def _run(args: argparse.Namespace, config: dict) -> None:
    """Run the install command."""
    test_mode = getattr(args, "test", False)
    base_dir = os.getcwd()
    
    # Discover all available skills from multiple sources
    discovered: List[dict] = []
    
    # Scan current directory
    discovered.extend(discover_skills_in_tree(base_dir, max_depth=3))
    
    # Scan discovery_dirs from config
    for discovery_dir in config.get("discovery_dirs", []):
        discovered.extend(discover_skills_in_tree(discovery_dir, max_depth=3))
    
    if not discovered:
        print("No skills discovered in current directory or discovery_dirs.")
        return
    
    # Filter by skill names if provided
    if args.skill:
        candidates = []
        for skill_name in args.skill:
            matching = [d for d in discovered if d["name"] == skill_name or d["folder_name"] == skill_name]
            if not matching:
                print(f"Skill '{skill_name}' not found.")
            else:
                candidates.extend(matching)
        
        if not candidates:
            return
    else:
        # Interactive mode - let user select multiple
        _install_interactive_multi(config, discovered, test_mode)
        return
    
    # Get agent/path selection from args or prompt
    selected_agents = None
    selected_paths = None
    
    if args.agent:
        selected_agents = [args.agent]
    if args.path_type:
        selected_paths = [args.path_type]
    
    if test_mode:
        print("\nTest mode - the following would be installed:\n")
    else:
        print(f"\nInstalling {len(candidates)} skill(s)...\n")
    
    installed = install_candidates(candidates, config, test_mode, selected_agents, selected_paths)
    
    if test_mode:
        print("\nRun without --test to actually install these skills.")


def _install_interactive_multi(config: dict, discovered: List[dict], test_mode: bool = False) -> None:
    """Interactive installation allowing multiple skill selection."""
    choices = []
    for item in discovered:
        desc = item["description"]
        desc_short = desc if len(desc) <= 80 else f"{desc[:77]}..."
        choices.append(f"{item['name']} [{item['rel_path']}] - {desc_short}")
    
    selected = select_multiple("Select skills to install:", choices, default=[choices[0]] if choices else None)
    
    if not selected:
        return
    
    candidates = [discovered[choices.index(choice)] for choice in selected if choice in choices]
    
    if not candidates:
        return
    
    # Ask for test mode if not already set
    if not test_mode:
        test_choice = select_option(
            "Run in test mode (preview only)?",
            ["no - actually install", "yes - just preview"],
            default="no - actually install",
        )
        test_mode = test_choice == "yes - just preview"
    
    if test_mode:
        print("\nTest mode - the following would be installed:\n")
    else:
        print(f"\nInstalling {len(candidates)} skill(s)...\n")
    
    installed = install_candidates(candidates, config, test_mode)
    
    if test_mode:
        print("\nRun without --test to actually install these skills.")


def _run_interactive(config: dict) -> None:
    """Interactive version of the install command."""
    base_dir = os.getcwd()
    
    # Discover all available skills from multiple sources
    discovered: List[dict] = []
    
    # Scan current directory
    discovered.extend(discover_skills_in_tree(base_dir, max_depth=3))
    
    # Scan discovery_dirs from config
    for discovery_dir in config.get("discovery_dirs", []):
        discovered.extend(discover_skills_in_tree(discovery_dir, max_depth=3))
    
    if not discovered:
        print("No skills discovered in current directory or discovery_dirs.")
        return
    
    _install_interactive_multi(config, discovered, test_mode=False)


command = Command(
    name="install",
    help="Install discovered skills",
    add_arguments=_add_arguments,
    run=_run,
    run_interactive=_run_interactive,
)
