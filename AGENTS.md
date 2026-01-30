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

- **Install for Dev**:
  ```bash
  cd skiller
  uv venv
  source .venv/bin/activate  # On Unix/macOS
  uv pip install -e .
  ```
- **Dependency Management**: Uses `pyproject.toml`.

### Skiller CLI Commands

```bash
# List all available commands
skiller --help

# Discover skills in a directory
skiller discovery [DIR]

# List installed skills
skiller list [--agent AGENT]

# Install discovered skills (interactive or with arguments)
skiller install [skill_name ...] [--agent AGENT] [--path-type user|project] [--test]

# Remove installed skills (interactive or with arguments)
skiller remove [skill_name] [--agent AGENT] [--path-type user|project|all] [--test]

# Crawl external sites for skills
skiller crawl [--file skill-sites.md] [--test] [--limit N]

# Search for skills in the crawled index
skiller search [query] [--json]
```

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
  uv venv
  source .venv/bin/activate  # On Unix/macOS
  uv pip install -e .
  ```

### Linting (Recommended)

- **Python**:
  ```bash
  ruff check .  # If installed
  # or
  flake8 .
  ```

### External Skill Discovery

The skiller CLI can discover skills from external sources:

- **Crawl**: Fetch skills from GitHub repositories listed in `skill-sites.md`
  ```bash
  skiller crawl                    # Crawl all repos
  skiller crawl --limit 5        # Crawl first 5 repos only
  skiller crawl --test            # Preview without saving to index
  skiller crawl --limit 2 --test # Test mode with limit
  ```
- **Search**: Query the crawled skill index with JSON output
  ```bash
  skiller search <query>
  skiller search youtube --json
  ```

Skills are indexed in `skiller/skiller_index.json` which is auto-generated during crawl operations.

**Crawl Features:**
- **GitHub API Integration**: Uses Git Tree API for efficient single-request repository scanning
- **Dynamic Branch Detection**: Automatically detects default branch (master/main) for each repository
- **Parallel Fetching**: Concurrent skill description fetching with configurable workers (--workers N)
- **Rate Limiting**: Exponential backoff for GitHub API rate limits
- **YAML Frontmatter Parsing**: Extracts skill metadata from SKILL.md files
- **Validation**: Validates all skill entries before saving to index
- **Incremental Saving**: Saves skills to index after each repository is crawled

### Skiller Configuration

Skiller loads configuration from `skiller_config.json` with the following options:

```json
{
  "custom_subdirs": ["dev"],
  "discovery_dirs": ["/Users/johannwaldherr/code/skale-skills"],
  "agent_dirs": {
    "opencode": {
      "user": ["~/.config/opencode/skill"],
      "project": [".opencode/skill"]
    }
  }
}
```

**Configuration Keys:**
- `custom_subdirs`: Subdirectory patterns to search within a base directory
- `discovery_dirs`: List of absolute paths to scan for skills (used by install command)
- `agent_dirs`: Installation targets for each agent, with `user` and `project` path types

**Configuration Loading Priority:**
1. `SKILLER_CONFIG` environment variable
2. `skiller_config.json` (searches upward from CWD)
3. Packaged `skiller_config.json`
4. Built-in defaults

### Skiller CLI Features

- **Interactive TUI**: Uses questionary for rich menus with curses fallback
- **YAML Frontmatter Parsing**: Extracts skill metadata from `SKILL.md` files
- **Tree-based Discovery**: Scans directories up to configurable max depth (default: 3)
- **GitHub API Crawling**: Efficient Git Tree API with parallel fetching, rate limiting, and exponential backoff
- **Test Mode**: Preview install/remove operations without making changes (`--test` flag)
- **Multi-agent/Path Targeting**: Install or remove skills across multiple agents and path types simultaneously

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
