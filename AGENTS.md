# Skale Skills - Agent Instructions

This repo contains **our own skills** (actively developed) and the `skiller` CLI.
External skills (docx, xlsx, etc.) should be installed from upstream — see `RECOMMENDED-SKILLS.md`.

## Our Skills

| Skill | Command | Tests | What |
|-------|---------|-------|------|
| fetch-url | `fetch-url "url"` | 49 | Web content extraction with smart fallback |
| web-search | `web-search "query"` | 38 | Web search via SearXNG + Duck API |
| youtube | `youtube "query"` | 32 | YouTube search via Invidious API with auto-fallback |
| vtd | `vtd transcript --url '...'` | 43 | Video/audio/transcript downloader (yt-dlp) |
| rodney | `rodney start/open/stop` | 32 | Headless Chrome automation |

## Credentials — credgoo (First-Class Citizen)

**All credentials go through credgoo.** No `.env` files with real tokens. No hardcoded secrets.

→ **Full guide: [docs/credgoo.md](docs/credgoo.md)** — setup, CLI reference, Python patterns, adding credentials to new skills
→ **Source:** [github.com/devskale/python-openutils](https://github.com/devskale/python-openutils) (`packages/credgoo/`)

Quick reference:

```bash
# First-time setup
credgoo --setup

# Get a key
credgoo WEB_SEARCH_BEARER

# Add to a new skill
credgoo MY_NEW_SERVICE_KEY
```

```python
# Standard pattern in Python
from credgoo import get_api_key
import contextlib, io

with contextlib.redirect_stdout(io.StringIO()):
    token = get_api_key("MY_SERVICE_KEY")
```

Resolution order: `env var` → `credgoo` → `.env` (last resort, gitignored)

Current services: `WEB_SEARCH_BEARER`, `FETCH_URL_BEARER`, `searx`

Rules: never commit real tokens, always gitignore `.env`, always suppress credgoo stdout in Python.

## Docs

| Doc | What |
|-----|------|
| [docs/credgoo.md](docs/credgoo.md) | Credential management — setup, CLI, Python patterns, adding to new skills |

## Guides

| Guide | What |
|-------|------|
| [guides/browser-tools-comparison.md](guides/browser-tools-comparison.md) | Agent browser tools compared (10 tools, feature matrix, Chrome 136+ breaking changes) |
| [guides/chrome-dev.md](guides/chrome-dev.md) | Chrome DevTools MCP setup |
| [guides/rodney-setup.md](guides/rodney-setup.md) | Rodney headless Chrome setup |
| [guides/vcl-agent-browser.md](guides/vcl-agent-browser.md) | Vercel agent-browser setup |

## Browser Automation — Chrome 136+ Breaking Change

> ⚠️ **`--remote-debugging-port=9222` on the default profile is no longer respected** (Chrome 136+, March 2025). Google blocked it for security — info-stealers were stealing cookies via CDP. You MUST use `--user-data-dir` pointing to a non-default directory. Even then, **App-Bound Encryption** (Chrome 136+) prevents decrypting cookies/passwords from a copied profile. For real-session reuse, use Chrome DevTools MCP `--autoConnect` (Chrome 146+) or `agent-browser --auto-connect state save`. Full details: [guides/browser-tools-comparison.md](guides/browser-tools-comparison.md).

## External Skills

Install from upstream, don't maintain locally:

```bash
# Browse and discover
skiller search <query>           # search crawled index
skiller crawl                    # refresh index from GitHub repos

# Install
skiller install <name>           # from index
npx @anthropic-ai/skills add <name>  # Anthropic skills
openskills install <org>/<repo>  # openskills CLI

# Also check: https://skills.sh
```

See `RECOMMENDED-SKILLS.md` for full list of sources and install commands.

## Running Tests

No global runner. Per-skill test suites:

```bash
bash tests/fetch-url/test.sh
bash tests/web-search/test.sh
bash tests/youtube/test.sh
bash tests/video-transcript-downloader/test.sh
bash tests/rodney/test.sh
```

Always run the relevant test after modifying a skill.

## Development Workflow

### Best Practices (from CONVENTION.md)

Every skill must have:
- `SKILL.md` — frontmatter (`name`, `description`, `version`) + short usage instructions
- Launcher script — symlink resolution, `--update`/`--selfcheck`, auto-update after 7 days
- `install.sh` — creates `~/.local/bin/<command>` symlink
- `.gitignore` — `.venv/`, `.env`, `uv.lock`, `*.egg-info/`, `.last-update`
- `tests/<name>/test.sh` — file structure, launcher flags, live smoke test, code quality

Never use: `readlink -f` (breaks macOS), `.env` with real tokens, `requirements.txt`.

### Python

- Type hints mandatory
- Google-style docstrings
- Credentials via [credgoo](#credentials--credgoo-first-class-citizen)

### SKILL.md

- Under 100 lines
- Short commands (`fetch-url "url"`, not `cd ~/.pi/... && uv run scripts/...`)
- Link all `references/` files

## API Docs

Reverse-engineered public APIs at `api/`:

- `api/ryanair/ryanair.md` — Ryanair fare search (free, no auth)

## Skiller CLI

```bash
cd skiller && uv venv && source .venv/bin/activate && uv pip install -e .
skiller --help
```

Key commands: `crawl`, `search`, `install`, `remove`, `list`.

See `skiller/` and `CONVENTION.md` for full details.
