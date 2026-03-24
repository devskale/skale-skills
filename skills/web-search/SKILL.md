---
name: web-search
description: Search the web with automatic backend selection. Works out-of-the-box with public SearXNG. Optional Duck API for advanced filters. Supports images, news, videos.
---

# Web Search

Search the web. Works globally without setup.

## Usage

```bash
web-search "your query"                    # Basic search
web-search "cats" --categories images      # Image search
web-search "AI news" --categories news     # News search
web-search "query" --max 20                # More results
web-search "query" -v                      # Verbose (show backend)
```

## Options

| Option | Description |
|--------|-------------|
| `--max N` | Max results (default: 10) |
| `--categories CAT` | images, news, videos |
| `--time-range DAY/WEEK/MONTH/YEAR` | Time filter |
| `--json` | Output raw JSON |
| `-v, --verbose` | Show backend used |

### Advanced (requires Duck API token)

| Option | Description |
|--------|-------------|
| `--site DOMAIN` | Filter by domain |
| `--filetype EXT` | Filter by file type (pdf, txt, etc.) |
| `--exact` | Exact phrase match |
| `--timelimit D/W/M/Y` | Time filter |

## Credentials (Optional)

### Duck API - Advanced Filters

```bash
credgoo add WEB_SEARCH_BEARER
```

### Private SearXNG - Better Reliability

```bash
credgoo add searx
# Enter: http://localhost:8080@username@password
```

## Install

```bash
cd ~/.pi/agent/skills/web-search
./install.sh
ln -sf $(pwd)/search ~/.local/bin/web-search  # Make global
```
