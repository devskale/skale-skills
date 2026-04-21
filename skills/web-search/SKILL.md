---
name: web-search
description: Search the web with automatic backend selection. Works out-of-the-box with public SearXNG. Optional Duck API for advanced filters. Supports images, news, videos.
metadata:
  author: skale
  version: "2.0"
---

# Web Search

Search the web. Works globally.

## Setup

### 1. Install the skill

```bash
cd ~/.pi/agent/skills/web-search
./install.sh
ln -sf $(pwd)/search ~/.local/bin/web-search  # Make global
```

> `./install.sh` runs `uv sync` which installs credgoo automatically. No separate install needed.

### 2. Configure backends (optional but recommended)

Public SearXNG instances are used by default — no setup needed. For better reliability and rate limits, configure a private SearXNG instance:

**Option A: Via credgoo**
```bash
credgoo add searx
# Enter URL@username@password, e.g.: http://localhost:8080@searxng@searxng23
```

**Option B: Via config file** (`~/.config/api_keys/searx.json`)
```json
{
  "url": "https://your-instance.example.com",
  "username": "searxng",
  "password": "your-password"
}
```

**Option C: Via environment variable**
```bash
export SEARXNG_URL="https://your-instance.example.com@username@password"
```

**Duck API** (for advanced filters like `--site`, `--filetype`):
```bash
credgoo add WEB_SEARCH_BEARER
```

### 3. Verify

```bash
web-search "test query" -v   # Should show: Backend: searxng
```

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
| `--time-range RANGE` | Time filter (lowercase: day, week, month, year) |
| `--json` | Output raw JSON |
| `-v, --verbose` | Show backend used |

### Advanced (requires Duck API token)

| Option | Description |
|--------|-------------|
| `--site DOMAIN` | Filter by domain |
| `--filetype EXT` | Filter by file type (pdf, txt, etc.) |
| `--exact` | Exact phrase match |
| `--timelimit D/W/M/Y` | Time filter |

## Edge Cases

- `--time-range` values must be **lowercase**: `day`, `week`, `month`, `year` (not `DAY`, `WEEK`, etc.)
- If all SearXNG instances fail, ensure at least one backend is reachable. Private instance recommended.
