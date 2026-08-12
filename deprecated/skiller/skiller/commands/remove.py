"""Remove command implementation to uninstall skills."""

from __future__ import annotations

import argparse
import os
import shutil
from typing import List, Optional, Tuple

from skiller.commands.base import Command
from skiller.core import parse_frontmatter, prompt_agents_and_paths
from skiller.ui import select_multiple, select_option


def _add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "skill",
        nargs="?",
        help="Name of skill to remove (optional, will prompt if not provided)",
    )
    parser.add_argument(
        "--agent",
        help="Agent to remove from (optional, will prompt if not provided)",
    )
    parser.add_argument(
        "--path-type",
        choices=["user", "project", "all"],
        help="Path type to remove from (optional, will prompt if not provided)",
    )
    parser.add_argument(
        "--test",
        action="store_true",
        help="Test mode - show what would be removed without actually removing",
    )


def _find_installed_skills(config: dict) -> List[dict]:
    """Find all installed skills across all agents and paths."""
    skills = []
    agent_dirs = config.get("agent_dirs", {}) or {}
    
    for agent_name, agent_config in agent_dirs.items():
        if not isinstance(agent_config, dict):
            continue
        
        for path_type in ["user", "project"]:
            for path in agent_config.get(path_type, []):
                path_expanded = os.path.expanduser(path)
                if not os.path.isdir(path_expanded):
                    continue
                
                try:
                    items = os.listdir(path_expanded)
                    for item in items:
                        skill_path = os.path.join(path_expanded, item)
                        if not os.path.isdir(skill_path):
                            continue
                        
                        skill_md = os.path.join(skill_path, "SKILL.md")
                        display_name = item
                        description = "(no description)"
                        
                        if os.path.isfile(skill_md):
                            fm = parse_frontmatter(skill_md)
                            if fm and isinstance(fm, dict):
                                display_name = fm.get("name") or item
                                raw_desc = fm.get("description")
                                if raw_desc:
                                    description = str(raw_desc).replace("\n", " ")
                        
                        skills.append({
                            "name": display_name,
                            "folder_name": item,
                            "agent": agent_name,
                            "path_type": path_type,
                            "path": path_expanded,
                            "full_path": skill_path,
                            "description": description,
                        })
                except PermissionError:
                    pass
    
    return skills


def _remove_skill(skill_info: dict, test_mode: bool = False) -> Tuple[str, Optional[str]]:
    """Remove a skill from its location.
    
    Returns:
        Tuple of (status, message) where status is one of: removed, not_found, error
    """
    skill_path = skill_info["full_path"]
    
    if not os.path.exists(skill_path):
        return "not_found", f"Skill not found at {skill_path}"
    
    if test_mode:
        return "test", f"Would remove {skill_info['name']} from {skill_info['agent']} ({skill_info['path_type']})"
    
    try:
        shutil.rmtree(skill_path)
        return "removed", f"Removed {skill_info['name']} from {skill_info['agent']} ({skill_info['path_type']})"
    except OSError as exc:
        return "error", f"Failed to remove {skill_info['name']}: {exc}"


def _run(args: argparse.Namespace, config: dict) -> None:
    """Run the remove command."""
    test_mode = getattr(args, "test", False)
    
    # If skill name provided directly
    if args.skill:
        skills = _find_installed_skills(config)
        matching = [s for s in skills if s["name"] == args.skill or s["folder_name"] == args.skill]
        
        if not matching:
            print(f"Skill '{args.skill}' not found in any installation location.")
            return
        
        # Filter by agent if specified
        if args.agent:
            matching = [s for s in matching if s["agent"] == args.agent]
        
        # Filter by path type if specified
        if args.path_type and args.path_type != "all":
            matching = [s for s in matching if s["path_type"] == args.path_type]
        
        if not matching:
            print(f"Skill '{args.skill}' not found in specified location.")
            return
        
        removed_any = False
        for skill in matching:
            status, message = _remove_skill(skill, test_mode)
            if status in ("removed", "test"):
                removed_any = True
            print(f"  {message}")
        
        if not removed_any and not test_mode:
            print("No skills were removed.")
        return
    
    # Interactive mode
    skills = _find_installed_skills(config)
    
    if not skills:
        print("No installed skills found.")
        return
    
    skill_names = sorted(set(s["name"] for s in skills))
    selected_names = select_multiple(
        "Select skills to remove:",
        skill_names,
        default=[skill_names[0]] if skill_names else None,
    )
    
    if not selected_names:
        return
    
    selected_skills = [s for s in skills if s["name"] in selected_names]
    
    if test_mode:
        print("\nTest mode - the following would be removed:\n")
    else:
        print(f"\nRemoving {len(selected_skills)} skill(s)...\n")
    
    removed_any = False
    for skill in selected_skills:
        status, message = _remove_skill(skill, test_mode)
        if status in ("removed", "test"):
            removed_any = True
        print(f"  {message}")
    
    if test_mode:
        print("\nRun without --test to actually remove these skills.")
    elif not removed_any:
        print("No skills were removed.")


def _run_interactive(config: dict) -> None:
    """Interactive version of the remove command."""
    skills = _find_installed_skills(config)
    
    if not skills:
        print("No installed skills found.")
        return
    
    # Ask for test mode
    test_choice = select_option(
        "Run in test mode (preview only)?",
        ["no - actually remove", "yes - just preview"],
        default="no - actually remove",
    )
    test_mode = test_choice == "yes - just preview"
    
    skill_names = sorted(set(s["name"] for s in skills))
    selected_names = select_multiple(
        "Select skills to remove:",
        skill_names,
        default=None,
    )
    
    if not selected_names:
        return
    
    selected_skills = [s for s in skills if s["name"] in selected_names]
    
    if test_mode:
        print("\nTest mode - the following would be removed:\n")
    else:
        print(f"\nRemoving {len(selected_skills)} skill(s)...\n")
    
    removed_any = False
    for skill in selected_skills:
        status, message = _remove_skill(skill, test_mode)
        if status in ("removed", "test"):
            removed_any = True
        print(f"  {message}")
    
    if test_mode:
        print("\nRun without --test to actually remove these skills.")
    elif not removed_any:
        print("No skills were removed.")


command = Command(
    name="remove",
    help="Remove installed skills",
    add_arguments=_add_arguments,
    run=_run,
    run_interactive=_run_interactive,
)
