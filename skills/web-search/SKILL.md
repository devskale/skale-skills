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
```

The install script will:
- Ensure `uv` is available (installs it if missing)
- Sync dependencies (`credgoo`, `requests`) into a local venv
- Create a `web-search` symlink in `~/.local/bin/` (auto-added to PATH on most systems)
- Run a quick verification search

> **Prerequisites:** `uv` (auto-installed if missing), `~/.local/bin` in your `$PATH`.
> If `web-search` is not found after install, add `export PATH="$HOME/.local/bin:$PATH"` to your shell profile.

### 2. Configure backends (optional but recommended)

Public SearXNG instances are used by default — no setup needed. For better reliability and rate limits, configure a private SearXNG instance:

**Option A: Via credgoo** (recommended)
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
web-search "test query" -v
# Output should include: # Backend: searxng   (or duck if token is set)
```

### Troubleshooting

| Problem | Fix |
|---------|-----|
| `web-search: command not found` | Add `~/.local/bin` to PATH: `export PATH="$HOME/.local/bin:$PATH"` |
| `uv: command not found` | Run install again — it auto-installs uv, or manually: `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `No solution found when resolving dependencies` | Update the skill: `cd ~/.pi/agent/skills/web-search && git pull && ./install.sh` |
| All SearXNG instances fail | Configure a private instance (see Option A–C above) or add a Duck API token |

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
| `--page N` | Results page (default: 1) |
| `--categories CAT` | images, news, videos |
| `--time-range RANGE` | Time filter (day, week, month, year) — works on both backends |
| `--language LANG` | Search language (default: en). SearXNG backend only. |
| `--region CODE` | Region (e.g., us-en, de-de). Default: wt-wt. |
| `--json` | Output raw JSON |
| `-v, --verbose` | Show backend used (printed to stderr) |
| `--api` | Force Duck API backend |
| `--searxng` | Force SearXNG backend |
| `--engines LIST` | Comma-separated engines (SearXNG only, e.g., google,bing) |

### Advanced (requires Duck API token)

| Option | Description |
|--------|-------------|
| `--site DOMAIN` | Filter by domain |
| `--filetype EXT` | Filter by file type (pdf, txt, etc.) |
| `--inurl TEXT` | URL must contain text |
| `--exclude TERMS` | Comma-separated terms to exclude |
| `--exact` | Exact phrase match |
| `--timelimit D/W/M/Y` | Time filter shorthand (Duck API only). Prefer `--time-range`. |

> **Time filters:** `--time-range day/week/month/year` works on both backends (auto-mapped for Duck API). `--timelimit d/w/m/y` is Duck API only. Prefer `--time-range`.
>
> **Duck API filters** (`--site`, `--filetype`, `--inurl`, `--exclude`, `--exact`) are silently ignored on SearXNG with a warning.

## Edge Cases

- `--time-range` values must be **lowercase**: `day`, `week`, `month`, `year` (not `DAY`, `WEEK`, etc.)
- If all SearXNG instances fail, ensure at least one backend is reachable. Private instance recommended.
- `-v, --verbose` output goes to **stderr** — safe to pipe stdout.
- Exit codes: `0` = success, `1` = search error (backend failure, auth error, all instances down).

## Future Considerations

### Obscura (headless browser)

https://github.com/h4ckf0r0day/obscura — Rust + V8 headless browser, single binary, no Chrome needed.

**Pros:** 0.2s static pages, 16 MB RAM, built-in stealth/tracker blocking, CDP server mode.

**Blockers (as of v0.1.0):**
- `--eval` is single-expression only (agents need IIFE wrapping for multi-statement JS)
- Google.com completely broken (`document.body` is `null`)
- Stealth doesn't bypass bot detection (arh.antoinevastel.com detects headless, Cloudflare fails)
- New Reddit, Amazon, X, Stack Overflow all fail
- CDP `/json/new`/`/json/close` broken via HTTP
- No form interaction, screenshots, or persistent sessions
- No parallel `scrape` in pre-built binaries

**When to revisit:** After v1.0+ with multi-statement eval, real anti-bot bypass, and Google rendering. For now, rodney + Chrome is the better browser automation tool.
