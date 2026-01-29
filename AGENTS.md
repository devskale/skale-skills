# Skale Skills - Agent Instructions

This repository contains reusable skills for AI agents and the `skiller` CLI tool to manage them.
As an agent working in this codebase, adhere to the following guidelines.

## 1. Repository Structure

- `skills/`: The core product. Contains skill directories.
  - Structure: `skills/<skill-name>/`
  - Required: `SKILL.md` (with YAML frontmatter)
  - Optional: `scripts/` (executable code), `references/` (docs), `assets/` (files).
- `skiller/`: Python CLI tool for skill management.
- `tests/`: Integration tests for skills.

## 2. Development Workflow

### Creating/Modifying Skills

- **Reference**: Always follow patterns in `skills/agent-skill-creator/SKILL.md`.
- **SKILL.md**: Must have YAML frontmatter with `name` and `description`.
  - `name`: Matches directory name.
  - `description`: Concise, high-level summary.
- **Scripts**: Place executable code in `scripts/`.
  - Python: Use `#!/usr/bin/env python3`
  - Bash: Use `#!/usr/bin/env bash` and `set -e`.
  - Node: Use `#!/usr/bin/env node`.

### Running Tests

There is no global test runner. Tests are script-based per skill.

- **Locate Tests**: Check `tests/<skill-name>/` or `skills/<skill-name>/tests/`.
- **Run a Single Test**:
  ```bash
  # Example for video-transcript-downloader
  bash tests/video-transcript-downloader/test.sh
  ```
- **Creating Tests**:
  - Create a `test.sh` in `tests/<skill-name>/`.
  - Ensure it cleans up output files.
  - Use assertions (exit 1 on failure).

### Python (Skiller CLI)

- **Install for Dev**: `uv pip install -e skiller` or `pip install -e skiller`.
- **Dependency Management**: Uses `pyproject.toml`.

## 3. Code Style Guidelines

### Python

- **Type Hints**: **MANDATORY** for all function arguments and return values.
  - Use `from typing import ...` or built-ins (Python 3.9+).
  - Use `Optional`, `List`, `Dict`, `Any` appropriately.
- **Docstrings**: Google Style.

  ```python
  def my_function(param: str) -> bool:
      """Short description.

      Args:
          param: Description of param.

      Returns:
          True if successful, False otherwise.
      """
  ```

- **Imports**: Sorted. Standard lib -> Third party -> Local.
- **Formatting**: 4 spaces indentation.
- **Error Handling**: Use specific exceptions. Avoid bare `except:`.

### JavaScript / Node

- **Module System**: ES Modules (`"type": "module"` in package.json).
- **Style**: Semicolons, 2 spaces indentation.

### SKILL.md Best Practices

- **Concise is Key**: Agents have limited context. Don't explain basic concepts.
- **Degrees of Freedom**:
  - _High_: Text instructions for flexible tasks.
  - _Medium_: Pseudocode for patterns.
  - _Low_: Scripts for fragile operations.

## 4. Operational Commands

### Build & Install

- **Skiller**:
  ```bash
  cd skiller
  pip install -e .
  ```

### Linting (Recommended)

- **Python**:
  ```bash
  ruff check .  # If installed
  # or
  flake8 .
  ```

## 5. Agent Behavior Rules

- **Proactive Testing**: Always run the relevant `test.sh` after modifying a skill.
- **File Integrity**: Do not modify `SKILL.md` frontmatter keys (`name`, `description`) unless renaming the skill.
- **Documentation**: If adding a new dependency, update the skill's `README.md` or installation instructions (e.g., `install.sh`).
- **Path Handling**: In scripts, always use absolute paths derived from the script location.
  ```bash
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ```
  ```python
  import os
  SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
  ```

## 6. Cursor / Copilot Rules

_No specific rules found in .cursor/rules or .github/copilot-instructions.md at this time._
_Follow the general best practices outlined above._
