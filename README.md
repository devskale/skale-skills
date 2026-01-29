# Skale Skills

A collection of reusable AI agent skills for enhancing coding and productivity workflows.

## Available Skills

- **agent-skill-creator** - Guide for creating effective skills for multiple AI agents
- **docx** - Comprehensive Word document creation, editing, and analysis
- **video-transcript-downloader** - Download videos, audio, subtitles, and transcripts
- **youtube** - Search YouTube videos via Invidious API
- **xlsx** - Spreadsheet creation, editing, and analysis
- **markdown-converter** - Convert documents to markdown
- **command-creator** - Create and manage command templates
- **readme-write** - Generate and update README.md files
- **searxng-search** - Search via SearXNG instance

## Using Skiller CLI

`skiller` is a Python CLI tool included in this repository for discovering, installing, and managing AI agent skills.

### Installation

```bash
cd skiller
uv venv
source .venv/bin/activate  # On Unix/macOS
uv pip install -e .
```

### Commands

```bash
# Show help
skiller --help

# Discover skills in a directory
skiller discovery [DIR]

# List installed skills across all agents
skiller list

# List installed skills for a specific agent
skiller list --agent opencode

# Install discovered skills (interactive or with arguments)
skiller install
skiller install docx xlsx --agent opencode --path-type user

# Test mode - preview what would be installed
skiller install --test docx

# Remove installed skills (interactive or with arguments)
skiller remove
skiller remove frontend-design --agent opencode

# Test mode - preview what would be removed
skiller remove --test frontend-design

# Crawl external sites for skills
skiller crawl

# Search the crawled skill index
skiller search <query>
skiller search youtube --json
```

### Configuration

Skiller loads configuration from `skiller_config.json` with the following schema:

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

Supported agents: opencode, qwen, claude, gemini, codex, trae.

## Installation

### Using OpenSkills (recommended)

OpenSkills provides universal skill management for multiple AI agents.

```bash
# Install all skills from this repository
openskills install johannwaldherr/skale-skills

# Install a specific skill
openskills install johannwaldherr/skale-skills/improve-skill

# Install from local directory (for development)
cd /Users/johannwaldherr/code/skale-skills/skills/improve-skill
openskills install file://$(pwd)

# Install to global directory (shared across all projects)
openskills install johannwaldherr/skale-skills --global

# Install to universal directory (multi-agent setup)
openskills install johannwaldherr/skale-skills --universal

# Non-interactive install (install all skills)
openskills install johannwaldherr/skale-skills --yes
```

### Using npx skills

The npx skills CLI supports installation from git repositories and local paths.

```bash
# Install all skills from this repository (interactive)
npx skills add johannwaldherr/skale-skills

# Install a specific skill
npx skills add johannwaldherr/skale-skills --skill improve-skill

# Install from local directory
npx skills add ./skills/improve-skill

# Install to global directory
npx skills add johannwaldherr/skale-skills -g

# Install to specific agents
npx skills add johannwaldherr/skale-skills -a claude-code -a opencode

# List available skills in repository
npx skills add johannwaldherr/skale-skills --list

# Non-interactive installation
npx skills add johannwaldherr/skale-skills --skill improve-skill -y
```

### Using ctx7

ctx7 is a CLI for the Context7 Skills Registry.

```bash
# Search for skills in the registry
ctx7 skills search improve-skill

# Install from registry (if published)
ctx7 skills install /johannwaldherr/skale-skills improve-skill

# Install to specific client
ctx7 skills install /johannwaldherr/skale-skills improve-skill --claude

# Install globally
ctx7 skills install /johannwaldherr/skale-skills improve-skill --global

# List installed skills
ctx7 skills list

# List installed skills for specific client
ctx7 skills list --claude

# Remove a skill
ctx7 skills remove improve-skill
```

### Install from local directory

```bash
# Copy skill directly to agent's skills directory
cp -r /path/to/skill ~/.claude/skills/
cp -r /path/to/skill ~/.cursor/skills/
cp -r /path/to/skill ~/.codex/skills/
cp -r /path/to/skill ~/.config/opencode/skill/
```

### Managing Skills

#### OpenSkills

```bash
# List installed skills
openskills list

# Read a skill's content
openskills read improve-skill

# Sync skills with AGENTS.md configuration
openskills sync

# Remove a skill (interactive)
openskills manage

# Remove a specific skill
openskills remove improve-skill
```

#### npx skills

```bash
# List all installed skills
npx skills list

# List only global skills
npx skills ls -g

# Filter by specific agents
npx skills ls -a claude-code -a cursor

# Remove a skill interactively
npx skills remove

# Remove a specific skill
npx skills remove improve-skill

# Remove from global scope
npx skills remove --global improve-skill

# Check for updates
npx skills check

# Update all skills
npx skills update
```

#### ctx7

```bash
# List installed skills
ctx7 skills list

# List for specific client
ctx7 skills list --claude

# Show skill information
ctx7 skills info /johannwaldherr/skale-skills

# Remove a skill
ctx7 skills remove improve-skill

# Remove from specific client
ctx7 skills remove improve-skill --claude

# Remove globally
ctx7 skills remove improve-skill --global
```

## Supported Clients

The CLI automatically detects which AI coding assistants you have installed and offers to install skills for them:

| Client      | Skills Directory          |
| ----------- | ------------------------- |
| Claude Code | `.claude/skills/`         |
| Cursor      | `.cursor/skills/`         |
| Codex       | `.codex/skills/`          |
| OpenCode    | `.config/opencode/skill/` |
| Amp         | `.agents/skills/`         |
| Antigravity | `.agent/skills/`          |
| qwen        | `.qwen/skills/`           |
| trae        | `.trae/skills/`           |

## Related Resources

See [skill-sites.md](skill-sites.md) for:

- List of skill repositories
- Skill managers and tools
- Agent skill documentation links
