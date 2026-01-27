"""Configuration loading for skiller."""

from __future__ import annotations

import json
import os
import sys

DEFAULT_CONFIG: dict = {
    "custom_subdirs": ["dev"],
    "agent_dirs": {
        "default": {"user": ["~/.config/opencode/skill"], "project": [".opencode/skill"]},
        "opencode": {"user": ["~/.config/opencode/skill"], "project": [".opencode/skill"]},
        "qwen": {"user": ["~/.qwen/skills"], "project": [".qwen/skills"]},
        "claude": {"user": ["~/.claude/skills"], "project": [".claude/skills"]},
        "gemini": {"user": ["~/.gemini/skills"], "project": [".gemini/skills"]},
        "codex": {
            "user": ["~/.codex/skills", "/etc/codex/skills"],
            "project": [".codex/skills", "../.codex/skills"],
        },
        "trae": {"user": ["~/.trae/skills"], "project": [".trae/skills"]},
    },
}


def load_config() -> dict:
    """Load configuration for skiller.

    Preference order:
      1. Config path from SKILLER_CONFIG env var.
      2. Development config found in the current working tree, by searching
         upwards for either `skiller/skiller_config.json` or `skiller_config.json`.
      3. Packaged config next to the installed module (`skiller_config.json`).
      4. Builtin defaults.
    """
    explicit = os.environ.get("SKILLER_CONFIG")
    if explicit:
        if os.path.isfile(explicit):
            try:
                with open(explicit, "r", encoding="utf-8") as f:
                    return json.load(f)
            except json.JSONDecodeError:
                print(f"Error: Invalid JSON in {explicit}.", file=sys.stderr)
                sys.exit(1)
        else:
            print(
                f"Warning: SKILLER_CONFIG is set to {explicit} but the file does not exist; continuing to other lookups.",
                file=sys.stderr,
            )

    cur = os.path.abspath(os.getcwd())
    root = os.path.abspath(os.sep)
    while True:
        candidates = [
            os.path.join(cur, "skiller", "skiller_config.json"),
            os.path.join(cur, "skiller_config.json"),
        ]
        for cand in candidates:
            if os.path.isfile(cand):
                try:
                    with open(cand, "r", encoding="utf-8") as f:
                        return json.load(f)
                except json.JSONDecodeError:
                    print(f"Error: Invalid JSON in {cand}.", file=sys.stderr)
                    sys.exit(1)
        if cur == root:
            break
        cur = os.path.dirname(cur)

    packaged = os.path.join(os.path.dirname(__file__), "skiller_config.json")
    try:
        with open(packaged, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        print(
            f"Warning: Packaged configuration not found at {packaged}. Using builtin defaults.",
            file=sys.stderr,
        )
        return DEFAULT_CONFIG
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in {packaged}.", file=sys.stderr)
        sys.exit(1)
