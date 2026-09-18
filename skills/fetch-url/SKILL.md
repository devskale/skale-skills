---
name: fetch-url
version: "2.8.1"
description: "Bash skill — NOT an MCP tool: run `fetch-url \"url\"` in your shell. Fetch and extract readable text from any web page — auto-selects the best backend (w3m, lynx, jina, markdown, chrome) with smart fallback. Use when the user wants to read an article, docs, or scrape text from a page. Triggers on: fetch this URL, read this page, extract the text, scrape this site, get the article content. Works on Reddit, StackOverflow, GitHub, docs sites, and more."
---

# Fetch URL

```bash
fetch-url "https://example.com"          # That's it.
```

Extracts text from any webpage. Works globally after install. **No credentials needed** — the free tools (w3m, lynx, jina, markdown) cover most sites.

## Keep it simple

The default auto-selects the best tool per site. Don't add flags you don't need.

| ✗ Don't | ✓ Do |
|---------|------|
| `export PATH="$HOME/.local/bin:$PATH"; fetch-url "url" --tool jina -v 2>&1 \| head -100` | `fetch-url "url"` |
| `fetch-url "url" --tool auto --clean -v` | `fetch-url "url"` |

- **Output is already cleaned** (empty lines collapsed). No `head`, no `2>&1`.
- **No URL yet?** `web-search "query"` finds the page first — the two are a combo: search finds, fetch-url reads.
- **Tool auto-selects per site** (Reddit→w3m, GitHub→jina, StackOverflow→markdown). Reach for `--tool` only when the default output is poor.
- **JS/Cloudflare-protected site?** `fetch-url "url" --tool chrome` (or `--tool markdown --md-method browser`).

## Install & update

```bash
pi install git:github.com/devskale/skale-skills   # the pi package (loads the skill)
./install.sh                                      # run once from this dir → global `fetch-url` command (uv auto-installed)
fetch-url --update / --selfcheck                  # manual update / version+date (auto-updates every 7d)
```

## Usage

```bash
fetch-url "https://example.com"           # Auto-selects best tool
fetch-url "https://reddit.com/r/python"   # Redirects to old.reddit.com, uses w3m
fetch-url "https://news.ycombinator.com"  # Uses w3m (free, local)
fetch-url "URL" --tool jina              # Force specific tool
fetch-url "URL" -v                        # Verbose (shows tool + redirects)
```

## Options

| Option | Description |
|--------|-------------|
| `--tool NAME` | w3m, lynx, jina, markdown, chrome, chawan, api |
| `-v, --verbose` | Show tool selection and redirects |
| `--no-clean` | Keep empty lines AND skip noise stripping (raw output) |
| `--update` | Update the skill now |
| `--selfcheck` | Show version and last update |

## Tools (Auto-Selected)

Priority: free local tools first (w3m, lynx), then free APIs (jina, markdown), then chrome.

| Tool | Best For | Cost |
|------|----------|------|
| w3m | Reddit, HN, simple HTML sites | Free, local |
| lynx | Wikipedia, text-heavy sites | Free, local |
| jina | Docs, blogs, GitHub, Medium | Free API |
| markdown | StackOverflow, fallback | Free API (50/day) |
| api | Skale fetch endpoint (`amd.skale.dev`) | Free, needs credgoo key |
| chrome | Cloudflare/JS-protected sites | Free, needs Chrome |

## Site-Specific Behavior

Auto-selects per site (Reddit → old.reddit + w3m, GitHub → jina, StackOverflow → markdown, Cloudflare/JS → chrome). Full per-site rankings: [references/sites.md](references/sites.md) — **read when** a site returns poor output.

## Configure (optional)

```bash
credgoo FETCH_URL_BEARER            # for the 'api' tool (no credgoo? uv tool install "credgoo @ git+https://github.com/devskale/python-openutils.git#subdirectory=packages/credgoo")
brew install w3m lynx chawan       # optional local browsers for better fallback
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `fetch-url: command not found` | Run `./install.sh` once (creates the `fetch-url` command on PATH), then call `fetch-url "url"` — never the full path and never `export PATH=`. |
| gunzip error on GitHub | Use `--tool jina` |
| Empty result | Try `--tool jina` or `--tool chrome` |
| Dependency error | `fetch-url --update` |

## References

- [references/sites.md](references/sites.md) — per-site tool rankings. **Read when** a site returns poor output and you need to pick a better `--tool`.
- [references/github.md](references/github.md) — GitHub raw-URL patterns. **Read when** fetching GitHub file/README/directory content.
- [references/troubleshooting.md](references/troubleshooting.md) — detailed fixes. **Read when** a fetch fails or returns empty/garbled output.
