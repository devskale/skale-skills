# Skiller

Helper script to discover, install, and manage skills for AI agents.

## Setup

1. Ensure you have `uv` installed. If not, install it from https://pypi.org/project/uv/

2. Navigate to the `skiller` directory:

   ```bash
   cd skiller
   ```

3. Create a virtual environment using uv:

   ```bash
   uv venv
   ```

4. Activate the virtual environment:

   ```bash
   source .venv/bin/activate  # On Unix/macOS
   # or on Windows: .venv\Scripts\activate
   ```

5. Install the package in editable mode:

   ```bash
   uv pip install -e .
   ```

6. Run the script:

   ```bash
   skiller
   ```

   Running without arguments displays the help message.

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
# Discover skills in current directory
skiller discovery

# Discover skills in a specific directory
skiller discovery ../other-skills
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
# List all installed skills
skiller list

# List skills for a specific agent
skiller list --agent claude
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
# Interactive mode - select skills and agents
skiller install

# Install a specific skill
skiller install readme-write

# Install multiple skills
skiller install readme-write docx xlsx

# Test installation (dry run)
skiller install readme-write --test

# Install for a specific agent
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
# Interactive mode - select skills to remove
skiller remove

# Remove a specific skill
skiller remove readme-write

# Test removal (dry run)
skiller remove readme-write --test

# Remove from specific agent
skiller remove readme-write --agent claude --path-type user
```

### crawl
Crawl external sites to discover and index skills.

```bash
skiller crawl [--file FILE] [--delay SECONDS] [--test] [--limit N] [--workers N]
```

**Options:**
- `--file` - Path to markdown file containing skill sites (default: skill-sites.md)
- `--delay` - Delay in seconds between requests (default: 0.5)
- `--test` - Test mode - show what would be crawled without saving
- `--limit` - Limit number of repos to crawl (0 = no limit, default: 0)
- `--workers` - Number of parallel workers for fetching descriptions (default: 5)

**Example:**
```bash
# Crawl all repos from skill-sites.md
skiller crawl

# Crawl in test mode (preview only)
skiller crawl --test

# Crawl only 5 repos for quick testing
skiller crawl --limit 5

# Crawl with more parallelism
skiller crawl --workers 10

# Crawl with custom delay and limit
skiller crawl --delay 1.0 --limit 3
```

**Features:**
- **Efficient**: Uses GitHub Tree API (1 request per repo vs 10-50+ before)
- **Parallel**: Fetches skill descriptions concurrently
- **Validation**: Validates all discovered skills have required fields
- **Rate Limit Handling**: Respects GitHub rate limits with exponential backoff
- **Test Mode**: Preview results without saving to index

### search
Search for skills in the local index.

```bash
skiller search [query] [--json]
```

**Options:**
- `query` - Search query for skill names or descriptions
- `--json` - Output results in JSON format

**Example:**
```bash
# Search for skills
skiller search "spreadsheet"

# Search with JSON output
skiller search "video" --json
```

**Note:** The index is created by running `skiller crawl` first.

## Global Test Mode

All destructive operations support `--test` mode:

- `install --test` - Preview installations without copying files
- `remove --test` - Preview removals without deleting files
- `crawl --test` - Preview crawl results without saving to index

## Environment Variables

- `GITHUB_TOKEN` - Optional GitHub personal access token for higher rate limits
- `SKILLER_CONFIG` - Optional path to custom configuration file

## Configuration

Skiller uses a configuration file to define agent paths. The default configuration includes:

```json
{
  "custom_subdirs": ["dev"],
  "agent_dirs": {
    "default": {"user": ["~/.config/opencode/skill"], "project": [".opencode/skill"]},
    "opencode": {"user": ["~/.config/opencode/skill"], "project": [".opencode/skill"]},
    "qwen": {"user": ["~/.qwen/skills"], "project": [".qwen/skills"]},
    "claude": {"user": ["~/.claude/skills"], "project": [".claude/skills"]},
    "gemini": {"user": ["~/.gemini/skills"], "project": [".gemini/skills"]},
    "codex": {"user": ["~/.codex/skills", "/etc/codex/skills"], "project": [".codex/skills", "../.codex/skills"]},
    "trae": {"user": ["~/.trae/skills"], "project": [".trae/skills"]}
  }
}
```

**Configuration Search Order:**
1. `SKILLER_CONFIG` environment variable
2. Development tree: `skiller/skiller_config.json` or `skiller_config.json`
3. Packaged config: `skiller_config.json`

## Development

To modify the script, edit files in `skiller/` and reinstall:

```bash
uv pip install -e .
```

## Project Structure

```
skiller/
├── skiller/
│   ├── cli.py              # CLI entry point
│   ├── commands/             # Command implementations
│   │   ├── base.py       # Command dataclass
│   │   ├── discovery.py   # Discover skills
│   │   ├── install.py    # Install skills
│   │   ├── list_cmd.py   # List installed skills
│   │   ├── remove.py     # Remove skills
│   │   ├── crawl.py      # Crawl external sites
│   │   └── search.py     # Search index
│   ├── core.py             # Core helpers (parsing, validation)
│   ├── config.py           # Configuration loading
│   └── ui.py              # Interactive UI helpers
├── pyproject.toml        # Python package config
├── skiller_config.json   # Default configuration
└── skiller_index.json    # Generated skill index (after crawl)
```

## License

See project root for license information.
