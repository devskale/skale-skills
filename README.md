# Skale Skills

A pi package with skills, extensions, and prompts for AI coding agents. Works with [pi](https://pi.dev), Claude Code, Codex, OpenCode, and others.

## What's Included

### Skills

| Skill | Description |
|-------|-------------|
| **fetch-url** | Web content extraction with smart fallback (Reddit, SO, GitHub, docs) |
| **web-search** | Web search via SearXNG + Duck API |
| **youtube** | YouTube search via Invidious API with auto-fallback |
| **video-transcript-downloader** | Download videos, audio, subtitles, transcripts (yt-dlp) |
| **rodney** | Headless Chrome automation (scrape, screenshot, PDF, a11y) |
| **browser-use** | Persistent browser automation with session continuity |
| **todo** | TODO.md task tracking for multi-step work |
| **improve-skill** | Improve skills from session transcripts |
| **agent-skill-creator** | Guide for creating skills for any AI agent |
| **agents-md-init** | Create and update AGENTS.md files |
| **command-creator** | Create custom commands for Pi and OpenCode |
| **readme-write** | Generate and update README.md files |

### Extensions (Pi)

| Extension | Description |
|-----------|-------------|
| **statusline** | Custom footer with machine name, token stats, context usage |
| **imagegen** | Generate images from text (Pollinations/TU via uniinfer proxy); returns image + ASCII preview so the model can iterate. See [extensions/imagegen.md](extensions/imagegen.md) |

### Prompts

| Prompt | Description |
|--------|-------------|
| **learn** | Learning and study workflow |

## Installation

### Pi (native)

> See [docs/installation.md](docs/installation.md) for precedence rules and the
> `Tool "heartbeat" conflicts with ...` gotcha before editing settings files.

```bash
# Install everything
pi install git:github.com/devskale/skale-skills

# Try without installing
pi -e git:github.com/devskale/skale-skills
```

Selective install — edit `~/.pi/agent/settings.json`:

```json
{
  "packages": [{
    "source": "git:github.com/devskale/skale-skills",
    "extensions": ["extensions/statusline.ts", "extensions/imagegen.ts"],
    "skills": ["skills/fetch-url", "skills/web-search", "skills/youtube"],
    "prompts": []
  }]
}
```

Filtering: omit key = load all · `[]` = load none · `"!skills/todo"` = exclude

### Other Agents

```bash
# npx skills (Claude Code, Codex, etc.)
npx skills@latest add devskale/skale-skills

# OpenSkills
openskills install devskale/skale-skills

# Symlink individual skills (any agent)
ln -s /path/to/skale-skills/skills/fetch-url ~/.pi/agent/skills/fetch-url
ln -s /path/to/skale-skills/skills/fetch-url ~/.claude/skills/fetch-url
```

## More Skill Sources

See [RECOMMENDED-SKILLS.md](RECOMMENDED-SKILLS.md) for external skills and [guides/](guides/) for setup guides.

## Repo Layout

```
skills/          → 12 agent skills
extensions/      → pi extensions (statusline, imagegen)
prompts/         → prompt templates
guides/          → setup guides (browser tools, Chrome DevTools, Rodney)
api/             → reverse-engineered public APIs (Ryanair)
skiller/         → skill discovery CLI (Python)
tests/           → per-skill test suites
```
