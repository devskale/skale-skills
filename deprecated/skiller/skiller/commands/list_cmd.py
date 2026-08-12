"""List command implementation."""

from __future__ import annotations

import argparse
from typing import List

from skiller.commands.base import Command
from skiller.core import list_installed_skills_for_paths


def _add_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--agent",
        default="All",
        help="Agent name to list skills for (default: All)",
    )


def _run(args: argparse.Namespace, config: dict) -> None:
    agent_dirs = config.get("agent_dirs", {}) or {}
    choice = getattr(args, "agent", None) or "All"

    if choice == "All":
        paths: List[str] = []
        seen = set()
        for a in agent_dirs.values():
            if not isinstance(a, dict):
                continue
            for p in a.get("user", []) + a.get("project", []):
                if p not in seen:
                    seen.add(p)
                    paths.append(p)
        if not paths:
            print("No configured agent paths to list.")
            return
        list_installed_skills_for_paths(config, paths)
        return

    ad = agent_dirs.get(choice, {}) or {}
    paths = ad.get("user", []) + ad.get("project", [])
    if not paths:
        print(f"No configured paths for agent '{choice}'.")
        return
    list_installed_skills_for_paths(config, paths)


command = Command(
    name="list",
    help="List installed skills",
    add_arguments=_add_arguments,
    run=_run,
)
