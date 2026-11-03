---
name: fetch-url
version: "2.9.1"
description: "Bash skill — run `fetch-url \"url\"` in your shell (not an MCP tool). Fetch and extract readable text from any web page. Use when the user wants to read an article, docs, or scrape a page."
---

# Fetch URL

```bash
fetch-url "https://example.com"          # That's it.
```

Extracts text from any webpage. Works globally after install. **No credentials needed** — the free tools (w3m, lynx, jina, markdown) cover most sites.

## Keep it simple

- **Output is already cleaned.** No `head`, no `2>&1`. `fetch-url "url"` genügt. No URL yet? `web-search "query"` first — search finds, fetch-url reads.
- **Tool auto-selects per site** (Reddit→w3m, GitHub/docs→defuddle, StackOverflow→markdown). `--tool` only when the default output is poor.
- **JS/Cloudflare site?** `--tool chrome` (or `--tool markdown --md-method browser`).

## Install & update

```bash
pi install git:github.com/devskale/skale-skills   # the pi package (loads the skill)
./install.sh                                      # once from this dir → global `fetch-url` (uv auto-installed)
fetch-url --update / --selfcheck                  # manual update / version+date
```

## Usage

```bash
fetch-url "https://example.com"           # Auto-selects best tool
fetch-url "https://reddit.com/r/python"   # Redirects to old.reddit.com, uses w3m
fetch-url "URL" --tool jina              # Force specific tool (-v = verbose)
```

## Options

| Option | Description |
|--------|-------------|
| `--tool NAME` | w3m, lynx, defuddle, jina, markdown, chrome, chawan, api |
| `-v, --verbose` | Show tool selection and redirects |
| `--no-clean` | Keep empty lines AND skip noise stripping (raw output) |
| `--update` | Update the skill now |
| `--selfcheck` | Show version and last update |

## Tools (Auto-Selected)

Selection: site hints first (`settings.json`), else `auto` = **jina** (leanest on
JS-heavy docs). On failure the fallback chain runs local-first
(w3m, lynx, defuddle → jina, markdown, chawan) until the content check accepts.
Privacy: `auto`/jina/markdown send the URL to a third-party extractor — local-only
via `--tool w3m` / `--tool lynx` / `--tool defuddle`. Chrome is explicit-only.

| Tool | Best For | Cost |
|------|----------|------|
| w3m | Reddit, HN, simple HTML sites | Free, local |
| lynx | Wikipedia, text-heavy sites | Free, local |
| defuddle | GitHub, docs/article pages (local main-content extraction) | Free, local, needs Node |
| jina | Docs, blogs, GitHub, Medium | Free API |
| markdown | StackOverflow, fallback | Free API (50/day) |
| api | Skale fetch endpoint (`amd.skale.dev`) | Free, needs credgoo key |
| chrome | Cloudflare/JS-protected sites | Free, needs Chrome |

## Site-Specific Behavior

Auto-selects per site (Reddit → old.reddit + w3m, GitHub/docs → defuddle, StackOverflow → markdown, Cloudflare/JS → chrome). Full per-site rankings: [references/sites.md](references/sites.md) — **read when** a site returns poor output.

## Configure (optional)

```bash
credgoo FETCH_URL_BEARER            # for the 'api' tool (no credgoo? uv tool install "credgoo @ git+https://github.com/devskale/python-openutils.git#subdirectory=packages/credgoo")
brew install w3m lynx chawan       # optional local browsers for better fallback
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `command not found` | Run `./install.sh` once, then `fetch-url "url"` — never full path, never `export PATH=` |
| gunzip error on GitHub | `--tool defuddle` (default for GitHub) |
| Empty result | `--tool defuddle` / `--tool jina` / `--tool chrome` |

## References

- [references/sites.md](references/sites.md) — per-site tool rankings. **Read when** a site returns poor output and you need to pick a better `--tool`.
- [references/github.md](references/github.md) — GitHub raw-URL patterns. **Read when** fetching GitHub file/README/directory content.
- [references/troubleshooting.md](references/troubleshooting.md) — detailed fixes. **Read when** a fetch fails or returns empty/garbled output.
- [dev/inspirations.md](dev/inspirations.md) — extraction engines worth studying (Defuddle, …). Maintainer notes (`dev/` — agent never loads these).
