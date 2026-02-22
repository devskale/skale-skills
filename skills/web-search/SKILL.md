---
name: web-search
description: Search the web with automatic backend selection. Uses privacy-respecting SearXNG when available, otherwise DuckDuckGo. Supports rich filters including domain, filetype, time filters, and exclusions.
compatibility: Requires WEB_SEARCH_BEARER for DuckDuckGo; credgoo (searx key) for SearXNG
---

# Web Search

Simple, opinionated web search that automatically picks the best backend.

## Quick Start

```bash
cd <skill-dir>
uv run scripts/search.py "your query"
```

## Configuration

### SearXNG (Recommended - Privacy)
Configure in credgoo with key `searx`:
```
URL@USERNAME@PASSWORD
```
Example: `https://searx.example.com:8080@myuser@mypassword`

### DuckDuckGo (Fallback)
Create `.env` file with:
```
WEB_SEARCH_BEARER=your_token
```
Or set `WEB_SEARCH_BEARER` environment variable.

## Usage

```bash
# Basic search
uv run scripts/search.py "react hooks"

# Documentation search
uv run scripts/search.py "python tutorial" --site github.com

# Filter by file type
uv run scripts/search.py "ML transformers" --filetype pdf

# Recent news
uv run scripts/search.py "AI news" --timelimit d

# Exclude sites
uv run scripts/search.py "python tutorial" --exclude youtube,reddit

# Exact phrase
uv run scripts/search.py "error message" --exact

# Images
uv run scripts/search.py "cats" --categories images

# Recent specific topic
uv run scripts/search.py "climate" --time-range week
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

The skill automatically selects the best backend:
1. **SearXNG** - Used if credentials configured (privacy, more engines)
2. **DuckDuckGo** - Default fallback

User doesn't need to think about backends - just search.

## Examples

```bash
# Find documentation
uv run scripts/search.py "react useEffect" --site react.dev

# Find papers
uv run scripts/search.py "attention is all you need" --filetype pdf

# Troubleshooting
uv run scripts/search.py "TypeError NoneType" --exact --site stackoverflow.com

# Current events
uv run scripts/search.py "bitcoin" --timelimit d

# Images
uv run scripts/search.py "landscape photography" --categories images

# Multiple exclusions
uv run scripts/search.py "python async" --exclude youtube,twitter,reddit
```
