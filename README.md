# Skale Skills

A collection of reusable AI agent skills for enhancing coding and productivity workflows.

## Available Skills

- **agent-skill-creator** - Guide for creating effective skills for multiple AI agents
- **docx** - Comprehensive Word document creation, editing, and analysis
- **video-transcript-downloader** - Download videos, audio, subtitles, and transcripts
- **youtube** - Search YouTube videos via Invidious API
- **xlsx** - Spreadsheet creation, editing, and analysis
- **markdown-converter** - Convert markdown to various formats
- **command-creator** - Create and manage command templates
- **readme-write** - Generate and update README.md files
- **searxng-search** - Search via SearXNG instance

## Installation

### Install from local directory

```bash
npx openskills install ./path/to/skill
```

### Using skill managers

```bash
npx ctx7
```

or

```bash
npx skills
```

## Supported Clients

The CLI automatically detects which AI coding assistants you have installed and offers to install skills for them:

| Client      | Skills Directory    |
| ----------- | ------------------- |
| Claude Code | `.claude/skills/`   |
| Cursor      | `.cursor/skills/`   |
| Codex       | `.codex/skills/`    |
| OpenCode    | `.opencode/skills/` |
| Amp         | `.agents/skills/`   |
| Antigravity | `.agent/skills/`    |
| qwen        | `.qwen/skills/`     |
| trae        | `.trae/skills/`     |

## Related Resources

See [skill-sites.md](skill-sites.md) for:

- List of skill repositories
- Skill managers and tools
- Agent skill documentation links
