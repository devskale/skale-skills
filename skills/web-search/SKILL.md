---
name: web-search
description: Search the web with automatic backend selection. Duck API for general search, SearXNG for images/news/videos. Rich filters including site, filetype, timelimit.
compatibility: Requires uv for installation. Duck API needs WEB_SEARCH_BEARER token; SearXNG needs credgoo 'searx' key.
---

# Web Search

Unified web search with intelligent backend selection and rich filters.

## Installation

```bash
cd <skill-path>
./install.sh
```

## Credentials

**Duck API** (primary):
```bash
credgoo add WEB_SEARCH_BEARER
# Or: export WEB_SEARCH_BEARER=your_token
```

**SearXNG** (optional, for images/news):
```bash
credgoo add searx
# Format: URL@USERNAME@PASSWORD
```

## Usage

```bash
# Basic search
./search "react hooks"

# With filters
./search "python tutorial" --site github.com
./search "ML paper" --filetype pdf --timelimit m
./search "error fix" --exact
./search "tutorial" --exclude youtube,video

# Images/news (uses SearXNG automatically)
./search "cats" --categories images
./search "AI news" --categories news

# Force specific backend
./search "query" --api        # Duck API
./search "query" --searxng    # SearXNG
```

## Options

| Option | Description |
|--------|-------------|
| `--max N` | Max results (default: 10) |
| `--site DOMAIN` | Filter by domain |
| `--filetype EXT` | Filter by file type (pdf, txt, etc.) |
| `--inurl FRAGMENT` | Filter by URL substring |
| `--exclude TERMS` | Exclude comma-separated terms |
| `--exact` | Exact phrase match |
| `--timelimit D/W/M/Y` | Time filter (day/week/month/year) |
| `--region CODE` | Region (us-en, de-de, wt-wt) |
| `--categories CAT` | Category (images, news, videos) - triggers SearXNG |
| `--json` | Output raw JSON |
| `-v, --verbose` | Show backend used |

## Backend Selection

| Query Type | Backend | Reason |
|------------|---------|--------|
| General search | Duck API | Reliable results |
| `--categories images/news` | SearXNG | Better media aggregation |
| `--searxng` flag | SearXNG | Explicit choice |
| `--api` flag | Duck API | Explicit choice |

## Examples

```bash
# Code examples
./search "python asyncio" --site github.com

# Research papers
./search "transformer architecture" --filetype pdf

# Recent news
./search "AI regulation" --timelimit w

# Exact error messages
./search "TypeError: NoneType has no attribute" --exact

# Exclude video results
./search "python tutorial" --exclude youtube,video

# Debug backend selection
./search "test" -v
# Output: # Backend: duck
```

## Alias Setup

```bash
echo "alias ws='~/.pi/agent/skills/web-search/search'" >> ~/.zshrc
source ~/.zshrc

ws "your query" --site docs.python.org
```
