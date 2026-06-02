---
name: fetch-url
description: Fetch and extract readable text content from web pages. Auto-selects best tool with smart fallback. Use when the user wants to read articles, documentation, or scrape text content from web pages. Works on Reddit, StackOverflow, GitHub, docs sites, and more.
metadata:
  author: skale
  version: "2.6"
---

# Fetch URL

```bash
fetch-url "https://example.com"          # That's it.
```

Extracts text from any webpage. Works globally after install.

## Install

**Linux / macOS (bash):**
```bash
cd ~/.pi/agent/skills/fetch-url && ./install.sh
```

**Windows (cmd):**
```cmd
cd %USERPROFILE%\.pi\agent\skills\fetch-url && install.bat
```

Creates `fetch-url` in `~/.local/bin/` (`%USERPROFILE%\.local\bin\` on Windows). Requires `uv` (auto-installed).

## Update

```bash
fetch-url --update                       # Manual update (git pull + uv sync)
fetch-url --selfcheck                    # Show version + last update date
```

Auto-updates in background every 7 days.

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
| `--tool NAME` | w3m, lynx, jina, markdown, chrome, chawan |
| `-v, --verbose` | Show tool selection and redirects |
| `--no-clean` | Keep empty lines |
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
| chrome | Cloudflare/JS-protected sites | Free, needs Chrome |

## Site-Specific Behavior

| Site | Strategy |
|------|----------|
| Reddit | Auto-redirects to old.reddit.com, uses w3m |
| HN | w3m (clean output) |
| Wikipedia | jina (cleanest), lynx/w3m fallback |
| GitHub | jina (clean markdown) |
| StackOverflow | markdown (bypasses blocks) |
| Medium | jina |
| Cloudflare sites | Chrome headless |

## Configure (optional)

```bash
# Credgoo for API tool
credgoo add FETCH_URL_BEARER

# Optional browsers for better fallback
brew install w3m lynx chawan
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `fetch-url: command not found` | Add `~/.local/bin` to PATH |
| gunzip error on GitHub | Use `--tool jina` |
| Empty result | Try `--tool jina` or `--tool chrome` |
| Dependency error | `fetch-url --update` |

## Reference

See [references/sites.md](references/sites.md) for tool rankings per site.
See [references/github.md](references/github.md) for GitHub raw URL patterns.
See [references/troubleshooting.md](references/troubleshooting.md) for detailed fixes.
