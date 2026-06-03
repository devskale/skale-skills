---
name: web-search
description: Search the web with automatic backend selection. Works out-of-the-box with public SearXNG. Optional Duck API for advanced filters. Supports images, news, videos.
metadata:
  author: skale
  version: "2.1.0"
---

# Web Search

```bash
web-search "your query"              # That's it.
```

Works globally after install. No credentials needed (public SearXNG).

## Install

**Linux / macOS (bash):**
```bash
cd ~/.pi/agent/skills/web-search && ./install.sh
```

**Windows (cmd):**
```cmd
cd %USERPROFILE%\.pi\agent\skills\web-search && install.bat
```

Creates a `web-search` command in `~/.local/bin/` (`%USERPROFILE%\.local\bin\` on Windows). Requires `uv` (auto-installed).

## Update

```bash
web-search --update                  # Manual update (git pull + uv sync)
web-search --selfcheck               # Show version + last update date
```

Auto-updates in the background every 7 days. No search is blocked — the update runs in a detached process.

## Configure Backends (optional)

Public SearXNG works out of the box. For better reliability:

**Private SearXNG** (recommended):

```bash
credgoo searx
# Returns: URL@username@password
```

Or set `SEARXNG_URL` env var, or create `~/.config/api_keys/searx.json`.

**Duck API** (advanced filters):

```bash
credgoo WEB_SEARCH_BEARER
```

## Usage

```bash
web-search "react hooks tutorial"
web-search "cats" --categories images
web-search "AI news" --categories news
web-search "query" --max 20
web-search "query" --time-range day
web-search "query" -v                      # verbose (shows backend on stderr)
web-search "query" --json                  # raw JSON to stdout
```

## Options

| Option | Description |
|--------|-------------|
| `--max N` | Max results (default: 10) |
| `--page N` | Results page (default: 1) |
| `--categories CAT` | images, news, videos |
| `--time-range RANGE` | day, week, month, year — works on both backends |
| `--language LANG` | Search language (default: en). SearXNG only. |
| `--region CODE` | Region (e.g., us-en, de-de). Default: wt-wt. |
| `--json` | Output raw JSON |
| `-v, --verbose` | Show backend (printed to stderr) |
| `--api` | Force Duck API backend |
| `--searxng` | Force SearXNG backend |
| `--engines LIST` | Comma-separated engines (SearXNG only) |
| `--update` | Update the skill now |
| `--selfcheck` | Show version and last update |

### Advanced (requires Duck API token)

| Option | Description |
|--------|-------------|
| `--site DOMAIN` | Filter by domain |
| `--filetype EXT` | Filter by file type (pdf, txt, etc.) |
| `--inurl TEXT` | URL must contain text |
| `--exclude TERMS` | Comma-separated terms to exclude |
| `--exact` | Exact phrase match |
| `--timelimit D/W/M/Y` | Time filter shorthand (Duck API only). Prefer `--time-range`. |

> **Duck API filters** (`--site`, `--filetype`, `--inurl`, `--exclude`, `--exact`) are silently ignored on SearXNG with a warning.

## Edge Cases

- `--time-range` values must be **lowercase**: `day`, `week`, `month`, `year`
- `-v, --verbose` output goes to **stderr** — safe to pipe stdout
- Exit codes: `0` = success, `1` = search error

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `web-search: command not found` | Add `~/.local/bin` to PATH: `export PATH="$HOME/.local/bin:$PATH"` |
| `uv: command not found` | Run `install.sh` again — it auto-installs uv |
| Dependency errors | `web-search --update` |
| All SearXNG instances fail | Configure a private instance via `credgoo searx` |

## Reference

See [references/INDEX.md](references/INDEX.md) for detailed examples, region codes, backend comparison, and authentication options.
