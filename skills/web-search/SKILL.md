---
name: web-search
description: Search the web with automatic backend selection. Uses privacy-respecting SearXNG when available, otherwise DuckDuckGo. Supports rich filters including domain, filetype, time filters, and exclusions.
compatibility: Requires uv for installation. SearXNG needs credgoo with 'searx' key; DuckDuckGo needs WEB_SEARCH_BEARER env var.
---

# Web Search

Simple, opinionated web search that automatically picks the best backend.

## Installation

```bash
cd <skill-path>
./install.sh
```

Or manually:
```bash
cd <skill-path>
uv venv && uv pip install -e .
```

### Credentials

**SearXNG** (recommended for privacy):
```bash
credgoo add searx
# Format: URL@USERNAME@PASSWORD
# Example: https://searx.example.com:8002@searxng@searxng23
```

**DuckDuckGo** (fallback):
```bash
credgoo add WEB_SEARCH_BEARER
# Or: export WEB_SEARCH_BEARER=your_token
```

## Usage

```bash
# Basic search
./search "react hooks"

# With filters
./search "python tutorial" --site github.com
./search "ML transformers" --filetype pdf
./search "AI news" --timelimit d
./search "python tutorial" --exclude youtube,reddit
./search "TypeError NoneType" --exact
./search "cats" --categories images
./search "climate" --time-range week
```

## Options

| Option | Description |
|--------|-------------|
| `--max N` | Number of results (default: 10) |
| `--site DOMAIN` | Filter by domain |
| `--filetype TYPE` | Filter by file type (pdf, txt, etc.) |
| `--exclude TERMS` | Exclude comma-separated terms |
| `--exact` | Exact phrase matching |
| `--timelimit d\|w\|m\|y` | Time filter (day/week/month/year) |
| `--categories` | Category filter (images, news, videos) |
| `--time-range` | Time range (day, week, month, year) |
| `--json` | Output raw JSON |
| `--verbose` | Show which backend is being used |

## Backend Selection

Automatic selection:
1. **SearXNG** - Used if credentials configured (privacy, more engines)
2. **DuckDuckGo** - Default fallback

## Tip: Create an Alias

```bash
echo "alias web-search='~/.pi/agent/skills/web-search/search'" >> ~/.zshrc
source ~/.zshrc

# Then use:
web-search "your query" --site github.com
```
