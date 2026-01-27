"""Install command implementation."""

from __future__ import annotations

import argparse
import os

from skiller.commands.base import Command
from skiller.core import _gather_skill_candidates, copy_skill_tree
from skiller.ui import select_multiple, select_option


def _add_arguments(parser: argparse.ArgumentParser) -> None:
    del parser


def _run(args: argparse.Namespace, config: dict) -> None:
    del args
    _install_interactive(config)


def _prompt_agents_and_paths(config: dict) -> tuple[list[str], list[str]] | None:
    agent_dirs = config.get("agent_dirs", {}) or {}
    if not agent_dirs:
        print("No agent configurations available to install into.")
        return None
    agents = sorted(agent_dirs.keys())
    if not agents:
        print("No agents defined in configuration.")
        return None
    agent_default = [agents[0]]
    selected_agents = select_multiple(
        "Choose agent(s) to install for:", agents, default=agent_default
    )
    if not selected_agents:
        return None
    path_choices = ["user", "project"]
    selected_paths = select_multiple(
        "Choose path types to install into (user/project):",
        path_choices,
        default=["user"],
    )
    if not selected_paths:
        return None
    return selected_agents, selected_paths


def install_candidates(candidates: list[dict[str, str]], config: dict) -> None:
    selection = _prompt_agents_and_paths(config)
    if not selection:
        return
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
                    status, result_path = copy_skill_tree(candidate["path"], target)
                    if status == "installed":
                        installed_any = True
                        print(
                            f"Installed {candidate['name']} for agent '{agent}' ({path_type}) -> {result_path}"
                        )
                    elif status == "exists":
                        print(
                            f"Already installed {candidate['name']} for agent '{agent}' ({path_type}) -> {result_path}"
                        )
                    elif status == "same":
                        print(
                            f"Already installed {candidate['name']} for agent '{agent}' ({path_type}) -> {result_path}"
                        )
    if not had_targets:
        print("No install targets were available for the selected agents.")
    elif not installed_any:
        print("No installations were performed (targets already existed or failed).")


def _install_interactive(config: dict) -> None:
    base_dir = os.getcwd()
    subdirs = config.get("custom_subdirs") or [".opencode/skills", ".claude/skills"]
    candidates = _gather_skill_candidates(base_dir, subdirs)
    if not candidates:
        print("No discoverable skills found under the configured subdirectories.")
        return
    choices = []
    for candidate in candidates:
        desc = candidate["description"]
        desc_short = desc if len(desc) <= 80 else f"{desc[:77]}..."
        choices.append(f"{candidate['name']} [{candidate['rel_path']}] - {desc_short}")
    selected = select_option("Choose a skill to install:", choices)
    if not selected:
        return
    index = choices.index(selected)
    candidate = candidates[index]
    install_candidates([candidate], config)


command = Command(
    name="install",
    help="Install a discovered skill",
    add_arguments=_add_arguments,
    run=_run,
    run_interactive=_install_interactive,
)
