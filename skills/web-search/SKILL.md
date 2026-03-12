---
name: web-search
description: Search the web with automatic backend selection. Works out-of-the-box with public SearXNG. Optional Duck API for advanced filters. Supports images, news, videos.
---

# Web Search

Unified web search that works immediately without any setup. Uses public SearXNG instances by default.

## Quick Start

```bash
cd <skill-path>
./install.sh
./search "your query"
```

**That's it!** No credentials needed for basic usage.

## Credentials (Optional)

### Duck API - Advanced Filters

The Duck API provides advanced filters (`--site`, `--filetype`, `--exact`, etc.) but requires a token.

**Get token:** Contact your admin or use your private API endpoint.

**Configure:**
```bash
# Option 1: Using credgoo (recommended)
credgoo add WEB_SEARCH_BEARER
# Enter your token when prompted

# Option 2: Environment variable
export WEB_SEARCH_BEARER=your_token

# Option 3: Add to shell config
echo 'export WEB_SEARCH_BEARER=your_token' >> ~/.zshrc
```

### Private SearXNG - Better Reliability

Public instances may have rate limits. For better reliability, run your own SearXNG instance.

**Configure:**
```bash
# Option 1: Using credgoo (recommended)
credgoo add searx
# Enter: http://localhost:8080@username@password

# Option 2: Environment variable (no auth)
export SEARXNG_URL=http://localhost:8080

# Option 3: Environment variable (with auth)
export SEARXNG_URL=http://localhost:8080@username@password

# Option 4: Config file
mkdir -p ~/.config/api_keys
echo '{"url":"http://localhost:8080","username":"user","password":"pass"}' > ~/.config/api_keys/searx.json
```

## Usage

```bash
# Basic search (works without credentials)
./search "react hooks"

# With filters (requires Duck API token)
./search "python tutorial" --site github.com
./search "ML paper" --filetype pdf --timelimit m
./search "error fix" --exact

# Images/news (uses SearXNG)
./search "cats" --categories images
./search "AI news" --categories news

# Force specific backend
./search "query" --searxng    # Public SearXNG (no token needed)
./search "query" --api        # Duck API (requires token)
```

## Options

| Option | Description | Backend |
|--------|-------------|---------|
| `--max N` | Max results (default: 10) | All |
| `--site DOMAIN` | Filter by domain | Duck API |
| `--filetype EXT` | Filter by file type (pdf, txt, etc.) | Duck API |
| `--inurl FRAGMENT` | Filter by URL substring | Duck API |
| `--exclude TERMS` | Exclude comma-separated terms | Duck API |
| `--exact` | Exact phrase match | Duck API |
| `--timelimit D/W/M/Y` | Time filter | Duck API |
| `--categories CAT` | Category (images, news, videos) | SearXNG |
| `--time-range DAY/WEEK/MONTH/YEAR` | Time filter | SearXNG |
| `--json` | Output raw JSON | All |
| `-v, --verbose` | Show backend used | All |

## Backend Selection

| Scenario | Backend | Why |
|----------|---------|-----|
| No token configured | Public SearXNG | Works out-of-the-box |
| Token configured + general search | Duck API | Advanced filters |
| `--categories images/news/videos` | SearXNG | Better media aggregation |
| `--searxng` flag | SearXNG | Explicit choice |
| `--api` flag | Duck API | Explicit choice |

## Examples

```bash
# Quick search (no setup needed)
./search "how to learn python"

# News search
./search "AI news" --categories news --time-range day

# Image search
./search "cute cats" --categories images --max 5

# Research (requires Duck API token)
./search "transformer architecture" --filetype pdf --timelimit y

# Code examples (requires Duck API token)
./search "python asyncio" --site github.com

# Exact error messages (requires Duck API token)
./search "TypeError: NoneType has no attribute" --exact

# Debug backend selection
./search "test" -v
# Output: # Backend: searxng
#         _Instance: https://searx.be_
```

## Alias Setup

```bash
echo "alias ws='~/.pi/agent/skills/web-search/search'" >> ~/.zshrc
source ~/.zshrc

ws "your query"
```
