"""Core skill discovery and installation helpers."""

from __future__ import annotations

import os
import shutil
import sys
from typing import Iterable, List, Optional, Tuple

import yaml

# Import UI functions for prompting
_imported_ui = None


def _get_ui():
    """Lazy import UI functions to avoid circular imports."""
    global _imported_ui
    if _imported_ui is None:
        from skiller import ui
        _imported_ui = ui
    return _imported_ui


def prompt_agents_and_paths(
    config: dict,
    default_agents: Optional[List[str]] = None,
    default_paths: Optional[List[str]] = None
) -> Optional[Tuple[List[str], List[str]]]:
    """Prompt user to select agents and path types for installation/removal.
    
    Args:
        config: Configuration dictionary
        default_agents: Default agents to use (skip prompt if provided)
        default_paths: Default paths to use (skip prompt if provided)
    
    Returns:
        Tuple of (selected_agents, selected_paths) or None if cancelled.
    """
    ui = _get_ui()
    agent_dirs = config.get("agent_dirs", {}) or {}
    if not agent_dirs:
        print("No agent configurations available.")
        return None
    agents = sorted(agent_dirs.keys())
    if not agents:
        print("No agents defined in configuration.")
        return None
    
    selected_agents = default_agents
    if not selected_agents:
        agent_default = [agents[0]]
        selected_agents = ui.select_multiple(
            "Choose agent(s):", agents, default=agent_default
        )
        if not selected_agents:
            return None
    
    selected_paths = default_paths
    if not selected_paths:
        path_choices = ["user", "project"]
        selected_paths = ui.select_multiple(
            "Choose path types (user/project):",
            path_choices,
            default=["user"],
        )
        if not selected_paths:
            return None
    
    return selected_agents, selected_paths


def parse_frontmatter(file_path: str) -> Optional[dict]:
    """Parse YAML frontmatter (--- ... ---) from the top of a file.

    Returns the parsed YAML mapping or None if not present/invalid.
    """
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            content = f.read()
        if not content.startswith("---\n"):
            return None
        end_pos = content.find("\n---\n", 4)
        if end_pos == -1:
            return None
        frontmatter_str = content[4:end_pos]
        parsed = yaml.safe_load(frontmatter_str)
        if isinstance(parsed, dict):
            return parsed
        return None
    except Exception:
        return None


def discover_skills(dir_path: str, agent_subdirs: Iterable[str]) -> None:
    """Discover potential skills in the given directory.

    For each subdir in agent_subdirs, looks for that subdirectory under dir_path
    (e.g., dir_path/.opencode/skills) and lists any contained skill directories
    and whether they have valid SKILL.md frontmatter.
    """
    dir_path_exp = os.path.expanduser(dir_path)
    if not os.path.isdir(dir_path_exp):
        print(f"Error: Directory '{dir_path_exp}' does not exist.", file=sys.stderr)
        return

    found_any = False
    for sub in agent_subdirs:
        agent_path = os.path.join(dir_path_exp, sub)
        if os.path.exists(agent_path) and os.path.isdir(agent_path):
            print(f"\nFound agent directory: {agent_path}")
            found_any = True
            try:
                items = os.listdir(agent_path)
                skill_dirs = [item for item in items if os.path.isdir(os.path.join(agent_path, item))]
                if skill_dirs:
                    print("  Potential skills:")
                    for skill in sorted(skill_dirs):
                        skill_path = os.path.join(agent_path, skill)
                        skill_md = os.path.join(skill_path, "SKILL.md")
                        if os.path.isfile(skill_md):
                            fm = parse_frontmatter(skill_md)
                            if fm and "name" in fm and "description" in fm:
                                if fm["name"] == skill:
                                    desc = str(fm["description"]).replace("\n", " ")[:120]
                                    print(f"    - {skill}: {desc}")
                                else:
                                    print(f"    - {skill}: (frontmatter name mismatch)")
                            else:
                                print(f"    - {skill}: (invalid or missing frontmatter)")
                        else:
                            print(f"    - {skill}: (no SKILL.md)")
                else:
                    print("  No skill directories found.")
            except PermissionError:
                print(f"  Permission denied accessing {agent_path}.")
        else:
            print(f"\nNo agent directory found at: {os.path.join(dir_path_exp, sub)}")

    if not found_any:
        print("\nNo known agent directories found in the specified directory.")


def _format_relative_path(path: str, base_dir: str) -> str:
    """Return path relative to base_dir with a ./ prefix when appropriate."""
    rel_path = os.path.relpath(path, start=base_dir)
    if rel_path == ".":
        return "./"
    if rel_path.startswith("../"):
        return rel_path
    if not rel_path.startswith("./"):
        rel_path = f"./{rel_path}"
    return rel_path


def list_skills_simple(dir_path: str, agent_subdirs: Iterable[str]) -> None:
    """List skills with one line per skill: dir skill description."""
    dir_path_exp = os.path.expanduser(dir_path)
    if not os.path.isdir(dir_path_exp):
        print(f"Error: Directory '{dir_path_exp}' does not exist.", file=sys.stderr)
        return

    found_any = False
    for sub in agent_subdirs:
        agent_path = os.path.join(dir_path_exp, sub)
        if not os.path.isdir(agent_path):
            continue
        found_any = True
        try:
            items = os.listdir(agent_path)
            skill_dirs = [item for item in items if os.path.isdir(os.path.join(agent_path, item))]
            for skill in sorted(skill_dirs):
                skill_path = os.path.join(agent_path, skill)
                skill_md = os.path.join(skill_path, "SKILL.md")
                description = "(no description)"
                if os.path.isfile(skill_md):
                    fm = parse_frontmatter(skill_md)
                    if fm and isinstance(fm, dict):
                        raw_desc = fm.get("description")
                        if raw_desc:
                            description = str(raw_desc).replace("\n", " ")
                rel_agent_path = _format_relative_path(agent_path, dir_path_exp)
                print(f"{rel_agent_path} {skill} {description}")
        except PermissionError:
            print(f"Permission denied accessing {agent_path}.")
    if not found_any:
        print("No known agent directories found in the specified directory.")


def discover_skills_in_tree(base_dir: str, max_depth: int = 3) -> List[dict[str, str]]:
    """Discover skills under base_dir up to max_depth.

    A discovered skill is a directory containing SKILL.md with valid frontmatter
    that includes a description.
    """
    base_dir_exp = os.path.expanduser(base_dir)
    if not os.path.isdir(base_dir_exp):
        print(f"Error: Directory '{base_dir_exp}' does not exist.", file=sys.stderr)
        return []

    discovered: List[dict[str, str]] = []
    base_depth = base_dir_exp.rstrip(os.sep).count(os.sep)
    for root, dirs, files in os.walk(base_dir_exp):
        depth = root.rstrip(os.sep).count(os.sep) - base_depth
        if depth > max_depth:
            dirs[:] = []
            continue

        if "SKILL.md" in files:
            skill_md = os.path.join(root, "SKILL.md")
            fm = parse_frontmatter(skill_md)
            if not fm or not isinstance(fm, dict):
                continue
            name = fm.get("name") or os.path.basename(root)
            raw_desc = fm.get("description")
            if not raw_desc:
                continue
            desc = str(raw_desc).replace("\n", " ")
            rel_root = _format_relative_path(root, base_dir_exp)
            discovered.append(
                {
                    "name": str(name),
                    "description": desc,
                    "path": root,
                    "rel_path": rel_root,
                    "folder_name": os.path.basename(root),
                }
            )

    return discovered


def list_discovered_skills_in_tree(base_dir: str, max_depth: int = 3) -> None:
    """Discover skills under base_dir up to max_depth and print only valid skills."""
    discovered = discover_skills_in_tree(base_dir, max_depth=max_depth)
    if not discovered:
        print("No skills discovered in the specified directory.")
        return

    for item in sorted(discovered, key=lambda x: x["name"].lower()):
        print(f"{item['rel_path']} {item['name']} {item['description']}")


def _gather_skill_candidates(base_dir: str, subdirs: Iterable[str]) -> List[dict[str, str]]:
    """Return discovered skills under the given subdirectories."""
    candidates: List[dict[str, str]] = []
    for sub in subdirs:
        search_path = os.path.join(base_dir, sub)
        if not os.path.isdir(search_path):
            continue
        try:
            items = os.listdir(search_path)
        except PermissionError:
            print(f"Permission denied accessing {search_path}.")
            continue
        valid_dirs = [item for item in items if os.path.isdir(os.path.join(search_path, item))]
        for skill in sorted(valid_dirs):
            skill_path = os.path.join(search_path, skill)
            description = "(no description)"
            display_name = skill
            skill_md = os.path.join(skill_path, "SKILL.md")
            if os.path.isfile(skill_md):
                fm = parse_frontmatter(skill_md)
                if fm and isinstance(fm, dict):
                    display_name = fm.get("name") or skill
                    raw_desc = fm.get("description")
                    if raw_desc:
                        description = str(raw_desc).replace("\n", " ")
            candidates.append(
                {
                    "name": display_name,
                    "description": description,
                    "path": skill_path,
                    "rel_path": _format_relative_path(skill_path, base_dir),
                    "folder_name": os.path.basename(skill_path),
                }
            )
    return candidates


def list_installed_skills_for_paths(config: dict, paths: Iterable[str]) -> None:
    """List skills found under a list of directory paths.

    Each path is considered a skills root containing subdirectories for each skill.
    """
    path_to_label = {}
    for agent, ad in config.get("agent_dirs", {}).items():
        if not isinstance(ad, dict):
            continue
        for path_type in ["user", "project"]:
            for path in ad.get(path_type, []):
                expanded = os.path.expanduser(path)
                path_to_label[expanded] = f"{agent}[{path_type}]"

    any_found = False
    for p in paths:
        p_expanded = os.path.expanduser(p)
        if not os.path.isdir(p_expanded):
            label = path_to_label.get(p_expanded, p_expanded)
            print(f"(missing) {label}")
            continue
        try:
            items = os.listdir(p_expanded)
            skill_dirs = [item for item in items if os.path.isdir(os.path.join(p_expanded, item))]
            if skill_dirs:
                any_found = True
                label = path_to_label.get(p_expanded, p_expanded)
                print(f"\nSkills in {label}:")
                for skill in sorted(skill_dirs):
                    skill_md = os.path.join(p_expanded, skill, "SKILL.md")
                    if os.path.isfile(skill_md):
                        fm = parse_frontmatter(skill_md)
                        if fm and isinstance(fm, dict):
                            name = fm.get("name")
                            desc = fm.get("description", "")
                            desc_short = (
                                str(desc).replace("\n", " ")[:80] + "..."
                                if desc
                                else "(no description)"
                            )
                            if name and name == skill:
                                print(f"  - {skill}: {desc_short}")
                            else:
                                print(f"  - {skill}: (frontmatter missing or name mismatch)")
                        else:
                            print(f"  - {skill}: (invalid frontmatter)")
                    else:
                        print(f"  - {skill}: (no SKILL.md)")
            else:
                label = path_to_label.get(p_expanded, p_expanded)
                print(f"No skills found under {label}.")
        except PermissionError:
            label = path_to_label.get(p_expanded, p_expanded)
            print(f"Permission denied accessing {label}.")
    if not any_found:
        print("\nNo skills discovered in the provided paths.")


def copy_skill_tree(source: str, destination_root: str) -> tuple[str, Optional[str]]:
    """Copy the skill directory into the destination root, avoiding overrides.

    Returns a tuple of (status, path) where status is one of: installed, exists,
    same, error.
    """
    destination_root_exp = os.path.expanduser(destination_root)
    os.makedirs(destination_root_exp, exist_ok=True)
    destination_path = os.path.join(destination_root_exp, os.path.basename(source))
    if os.path.abspath(destination_path) == os.path.abspath(source):
        return "same", destination_path
    if os.path.exists(destination_path):
        return "exists", destination_path
    try:
        shutil.copytree(source, destination_path)
    except OSError as exc:
        print(f"  Failed to install into {destination_path}: {exc}")
        return "error", destination_path
    return "installed", destination_path
