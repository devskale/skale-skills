---
name: web-search
version: "2.2.2"
description: "Search the web with automatic backend selection — public SearXNG works out-of-the-box (no credentials); an optional Duck API adds advanced filters (site, filetype, inurl, exact). Returns text, image, news, or video results. Use when the user wants to search the web, look something up, or find images/news/videos. Triggers on: web search, search for, google, look up, find online, image/news/video search."
---

# Web Search

```bash
web-search "your query"
```

That's the whole command. No flags, no pipes, no `export PATH=`. Works out of the box — public SearXNG, no credentials.

## Keep it simple

The default is the right call ~90% of the time. Don't add flags you don't need.

| ✗ Don't | ✓ Do |
|---------|------|
| `export PATH="$HOME/.local/bin:$PATH"; web-search "q" --max 6 2>&1 \| head -60` | `web-search "q"` |
| `web-search "q" --max 10 --page 1 --region wt-wt` | `web-search "q"` |
| `web-search "q" --json \| head` | `web-search "q"` |

- **Output is already concise** (10 results, markdown). No `head`, no `2>&1`.
- **`web-search: command not found`?** Install once (below) or use the full path `~/.local/bin/web-search "q"`. Don't prefix every call with `export PATH=`.
- **Want fewer/more results?** `--max 5` / `--max 20` — but the default 10 is usually right.
- **Want images/news/video?** `--categories images` / `--categories news`.

## Install

This skill ships in the **skale-skills** pi package — install the repo once:

```bash
pi install git:github.com/devskale/skale-skills
```

That loads the skill into pi. To also get a global `web-search` shell command, run the installer from **this skill's own directory** (next to `SKILL.md`):

```bash
./install.sh        # → creates ~/.local/bin/web-search (uv auto-installed)
install.bat         # Windows, same directory
```

## Update

```bash
web-search --update                  # Manual update (git pull + uv sync)
web-search --selfcheck               # Show version + last update date
```

Auto-updates in the background every 7 days. No search is blocked — the update runs in a detached process.

## Usage

```bash
web-search "react hooks tutorial"             # default: 10 text results
web-search "cats" --categories images         # images
web-search "AI news" --categories news        # news
web-search "query" --max 20                   # more results
web-search "query" --time-range day           # last 24h
```

## Options (only if you need them)

| Option | Description |
|--------|-------------|
| `--max N` | Max results (default: 10) |
| `--categories CAT` | images, news, videos |
| `--time-range RANGE` | day, week, month, year (both backends) |
| `--json` | Raw JSON to stdout |
| `-v, --verbose` | Show backend on stderr |
| `--page N` | Results page (default: 1) |
| `--language LANG` | Search language (default: en). SearXNG only. |
| `--region CODE` | Region (us-en, de-de). Default: wt-wt. |
| `--engines LIST` | Comma-separated engines (SearXNG only) |
| `--api` / `--searxng` | Force a backend |
| `--update` | Update the skill now |
| `--selfcheck` | Show version and last update |

### Advanced filters (require Duck API token via `credgoo WEB_SEARCH_BEARER`)

| Option | Description |
|--------|-------------|
| `--site DOMAIN` | Filter by domain |
| `--filetype EXT` | Filter by file type (pdf, txt, etc.) |
| `--inurl TEXT` | URL must contain text |
| `--exclude TERMS` | Comma-separated terms to exclude |
| `--exact` | Exact phrase match |

> Duck-only filters (`--site`, `--filetype`, `--inurl`, `--exclude`, `--exact`) are silently ignored on SearXNG with a warning. Use `--api` to force the Duck backend.

## Configure backends (optional)

Public SearXNG works out of the box. For better reliability:

**Private SearXNG** (recommended):

```bash
credgoo searx        # Returns: URL@username@password
```

Or set the `SEARXNG_URL` env var (bare URL, or `URL@user@pass`).

**Duck API** (enables `--site`, `--filetype`, `--inurl`, `--exclude`, `--exact`):

```bash
credgoo WEB_SEARCH_BEARER
```

**No `credgoo` command?** Install it once (the skill prefers a global install):

```bash
uv tool install "credgoo @ git+https://github.com/devskale/python-openutils.git#subdirectory=packages/credgoo"
```

## Gotchas

- `--time-range` values are **lowercase**: `day`, `week`, `month`, `year`
- `-v, --verbose` output goes to **stderr** — safe to pipe stdout
- Duck-only filters are ignored on SearXNG (warning printed). Use `--api` to force Duck.
- Exit codes: `0` = success, `1` = search error

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `web-search: command not found` | Run `./install.sh` once, or call `~/.local/bin/web-search "q"`. Don't prefix calls with `export PATH=`. |
| `uv: command not found` | Run `install.sh` again — it auto-installs uv |
| Dependency errors | `web-search --update` |
| All SearXNG instances fail | Configure a private instance via `credgoo searx` |

## References

- [references/INDEX.md](references/INDEX.md) — worked examples, region/language codes, backend comparison, and authentication options. **Read when** you need region tuning, backend details, or advanced Duck-API filters (`--site`/`--filetype`/`--inurl`).
