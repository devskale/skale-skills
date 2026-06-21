# Skiller

Install and manage **your own** skills across multiple AI agents from one place.

Skiller's one unique job: take a skill that lives in a local directory and
install it into every agent's skill folder at once (pi, claude, opencode, qwen,
gemini, codex, trae). For discovering *external* skills, use
[skills.sh](https://skills.sh), `openskills`, or
`npx @anthropic-ai/skills add <name>` instead.

## Setup

Requires `uv` (https://pypi.org/project/uv/).

```bash
cd skiller
uv venv && source .venv/bin/activate
uv pip install -e .
skiller            # runs the interactive TUI when called with no args
```

Or install as a global command:

```bash
uv tool install -e .     # editable, tracks this checkout
```

## Commands

### discovery
Discover skills in a directory.

```bash
skiller discovery [dir]
```

**Options:**
- `dir` - Directory to scan for skills (default: current directory)
- `--test` - Test mode - show what would be installed

**Example:**
```bash
skiller discovery                    # scan current directory
skiller discovery ../other-skills    # scan a specific directory
```

### list
List installed skills across all configured agents.

```bash
skiller list [--agent AGENT]
```

**Options:**
- `--agent` - Agent name to list skills for (default: All)

**Example:**
```bash
skiller list                  # all agents
skiller list --agent claude   # one agent
```

### install
Install discovered skills to one or more agents.

```bash
skiller install [skill ...] [--agent AGENT] [--path-type user|project] [--test] [--workers N]
```

**Options:**
- `skill` - Name(s) of skill(s) to install (optional, will prompt if not provided)
- `--agent` - Agent to install for (optional, will prompt if not provided)
- `--path-type` - Path type to install to (optional, will prompt if not provided)
- `--test` - Test mode - show what would be installed without actually installing
- `--workers` - Number of parallel workers for fetching descriptions (default: 5)

**Example:**
```bash
skiller install                          # interactive
skiller install readme-write             # one skill
skiller install readme-write docx xlsx   # several at once
skiller install readme-write --test      # dry run
skiller install readme-write --agent claude --path-type user
```

### remove
Remove installed skills from agent directories.

```bash
skiller remove [skill] [--agent AGENT] [--path-type user|project|all] [--test]
```

**Options:**
- `skill` - Name of skill to remove (optional, will prompt if not provided)
- `--agent` - Agent to remove from (optional, will prompt if not provided)
- `--path-type` - Path type to remove from (optional, will prompt if not provided)
- `--test` - Test mode - show what would be removed without actually removing

**Example:**
```bash
skiller remove                          # interactive
skiller remove readme-write             # one skill
skiller remove readme-write --test      # dry run
skiller remove readme-write --agent claude --path-type user
```

## Global Test Mode

All destructive operations support `--test` mode:

- `install --test` - Preview installations without copying files
- `remove --test` - Preview removals without deleting files

## Environment Variables

- `SKILLER_CONFIG` - Optional path to a custom configuration file

## Configuration

Skiller uses a configuration file to define agent paths. The default configuration includes:

```json
{
  "custom_subdirs": ["dev"],
  "agent_dirs": {
    "default": {"user": ["~/.config/opencode/skill"], "project": [".opencode/skill"]},
    "opencode": {"user": ["~/.config/opencode/skill"], "project": [".opencode/skill"]},
    "pi":       {"user": ["~/.pi/skills"], "project": [".pi/skills"]},
    "qwen":     {"user": ["~/.qwen/skills"], "project": [".qwen/skills"]},
    "claude":   {"user": ["~/.claude/skills"], "project": [".claude/skills"]},
    "gemini":   {"user": ["~/.gemini/skills"], "project": [".gemini/skills"]},
    "codex":    {"user": ["~/.codex/skills", "/etc/codex/skills"], "project": [".codex/skills", "../.codex/skills"]},
    "trae":     {"user": ["~/.trae/skills"], "project": [".trae/skills"]}
  }
}
```

**Configuration Search Order:**
1. `SKILLER_CONFIG` environment variable
2. Development tree: `skiller/skiller_config.json` or `skiller_config.json`
3. Packaged config: `skiller_config.json`

## Discovering External Skills

Skiller no longer ships a crawler/index. To find skills maintained elsewhere:

```bash
# Live marketplaces (always current)
#   https://skills.sh

# Anthropic's official skills (docx, xlsx, ...)
npx @anthropic-ai/skills add <name>

# Multi-source installer
openskills install <org>/<repo>
```

## Development

To modify the script, edit files in `skiller/` and reinstall:

```bash
uv pip install -e .
```

## Project Structure

```
skiller/
├── skiller/
│   ├── cli.py            # CLI entry point
│   ├── commands/         # Command implementations
│   │   ├── base.py       # Command dataclass
│   │   ├── discovery.py  # Discover skills in a dir
│   │   ├── install.py    # Install skills to agents
│   │   ├── list_cmd.py   # List installed skills
│   │   └── remove.py     # Remove skills from agents
│   ├── core.py           # Core helpers (parsing, validation)
│   ├── config.py         # Configuration loading
│   └── ui.py             # Interactive UI helpers
├── pyproject.toml        # Python package config
└── skiller_config.json   # Default configuration
```

## License

See project root for license information.
