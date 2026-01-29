"""Configuration loading for skiller."""

from __future__ import annotations

import json
import os
import sys
from typing import Any, List, Tuple


class ConfigValidationError(Exception):
    """Raised when configuration validation fails."""

    def __init__(self, message: str, field: str | None = None) -> None:
        self.field = field
        super().__init__(message)


def _validate_is_list_of_strings(value: Any, field_name: str) -> List[str]:
    """Validate that value is a list of strings.

    Args:
        value: The value to validate
        field_name: Name of the field for error messages

    Returns:
        The validated list of strings

    Raises:
        ConfigValidationError: If validation fails
    """
    if not isinstance(value, list):
        raise ConfigValidationError(
            f"'{field_name}' must be a list, got {type(value).__name__}",
            field_name
        )

    for i, item in enumerate(value):
        if not isinstance(item, str):
            raise ConfigValidationError(
                f"'{field_name}[{i}]' must be a string, got {type(item).__name__}",
                f"{field_name}[{i}]"
            )

    return value


def _validate_agent_dir(agent_name: str, agent_config: Any) -> None:
    """Validate a single agent directory configuration.

    Args:
        agent_name: Name of the agent
        agent_config: The agent's configuration dict

    Raises:
        ConfigValidationError: If validation fails
    """
    if not isinstance(agent_config, dict):
        raise ConfigValidationError(
            f"agent_dirs['{agent_name}'] must be a dict, got {type(agent_config).__name__}",
            f"agent_dirs.{agent_name}"
        )

    allowed_keys = {"user", "project"}
    for key in agent_config.keys():
        if key not in allowed_keys:
            raise ConfigValidationError(
                f"agent_dirs['{agent_name}'] has unknown key '{key}'. "
                f"Allowed keys: {', '.join(sorted(allowed_keys))}",
                f"agent_dirs.{agent_name}.{key}"
            )

    for path_type in ["user", "project"]:
        if path_type in agent_config:
            paths = agent_config[path_type]
            if paths is not None:
                _validate_is_list_of_strings(
                    paths,
                    f"agent_dirs['{agent_name}']['{path_type}']"
                )


def _validate_agent_dirs(agent_dirs: Any) -> dict[str, Any]:
    """Validate the agent_dirs configuration section.

    Args:
        agent_dirs: The agent_dirs value from config

    Returns:
        The validated agent_dirs dict

    Raises:
        ConfigValidationError: If validation fails
    """
    if not isinstance(agent_dirs, dict):
        raise ConfigValidationError(
            f"'agent_dirs' must be a dict, got {type(agent_dirs).__name__}",
            "agent_dirs"
        )

    if not agent_dirs:
        raise ConfigValidationError(
            "'agent_dirs' cannot be empty - at least one agent must be configured",
            "agent_dirs"
        )

    for agent_name, agent_config in agent_dirs.items():
        if not isinstance(agent_name, str):
            raise ConfigValidationError(
                f"agent_dirs keys must be strings, got {type(agent_name).__name__}",
                "agent_dirs"
            )
        _validate_agent_dir(agent_name, agent_config)

    return agent_dirs


def validate_config(config: dict) -> Tuple[bool, List[str]]:
    """Validate a configuration dictionary.

    Args:
        config: The configuration dict to validate

    Returns:
        Tuple of (is_valid, list_of_error_messages)
    """
    errors: List[str] = []

    if not isinstance(config, dict):
        errors.append(f"Configuration must be a dict, got {type(config).__name__}")
        return False, errors

    if "custom_subdirs" in config:
        try:
            _validate_is_list_of_strings(config["custom_subdirs"], "custom_subdirs")
        except ConfigValidationError as e:
            errors.append(str(e))

    if "discovery_dirs" in config:
        try:
            _validate_is_list_of_strings(config["discovery_dirs"], "discovery_dirs")
        except ConfigValidationError as e:
            errors.append(str(e))

    if "agent_dirs" not in config:
        errors.append("Missing required field: 'agent_dirs'")
    else:
        try:
            _validate_agent_dirs(config["agent_dirs"])
        except ConfigValidationError as e:
            errors.append(str(e))

    allowed_keys = {"custom_subdirs", "discovery_dirs", "agent_dirs"}
    for key in config.keys():
        if key not in allowed_keys:
            errors.append(f"Unknown configuration key: '{key}'")

    return len(errors) == 0, errors


def validate_config_or_exit(config: dict, source: str) -> dict:
    """Validate configuration and exit on error.

    Args:
        config: The configuration dict to validate
        source: Description of the config source (for error messages)

    Returns:
        The validated config

    Raises:
        SystemExit: If validation fails
    """
    is_valid, errors = validate_config(config)

    if not is_valid:
        print(f"Error: Invalid configuration from {source}:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        print("\nConfiguration schema:", file=sys.stderr)
        print("  {", file=sys.stderr)
        print('    "custom_subdirs": ["subdir1", "subdir2"],  # optional', file=sys.stderr)
        print('    "agent_dirs": {                            # required', file=sys.stderr)
        print('      "agent_name": {', file=sys.stderr)
        print('        "user": ["~/.config/agent/skills"],     # optional', file=sys.stderr)
        print('        "project": [".agent/skills"]           # optional', file=sys.stderr)
        print('      }', file=sys.stderr)
        print('    }', file=sys.stderr)
        print("  }", file=sys.stderr)
        sys.exit(1)

    return config


DEFAULT_CONFIG: dict = {
    "custom_subdirs": ["dev"],
    "discovery_dirs": [],
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

    Returns:
        Validated configuration dictionary

    Raises:
        SystemExit: If configuration is invalid or JSON parsing fails
    """
    explicit = os.environ.get("SKILLER_CONFIG")
    if explicit:
        if os.path.isfile(explicit):
            try:
                with open(explicit, "r", encoding="utf-8") as f:
                    config = json.load(f)
                return validate_config_or_exit(config, f"SKILLER_CONFIG ({explicit})")
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
                        config = json.load(f)
                    return validate_config_or_exit(config, cand)
                except json.JSONDecodeError:
                    print(f"Error: Invalid JSON in {cand}.", file=sys.stderr)
                    sys.exit(1)
        if cur == root:
            break
        cur = os.path.dirname(cur)

    packaged = os.path.join(os.path.dirname(__file__), "skiller_config.json")
    try:
        with open(packaged, "r", encoding="utf-8") as f:
            config = json.load(f)
        return validate_config_or_exit(config, packaged)
    except FileNotFoundError:
        print(
            f"Warning: Packaged configuration not found at {packaged}. Using builtin defaults.",
            file=sys.stderr,
        )
        return validate_config_or_exit(DEFAULT_CONFIG, "builtin defaults")
    except json.JSONDecodeError:
        print(f"Error: Invalid JSON in {packaged}.", file=sys.stderr)
        sys.exit(1)
